/* iob_spi_main.c: driver for iob_spi
 * using device platform. No hardcoded hardware address:
 * 1. load driver: insmod iob_spi.ko
 * 2. run user app: ./user/user
 */

#include <linux/cdev.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/ioport.h>
#include <linux/kernel.h>
#include <linux/mod_devicetable.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/platform_device.h>
#include <linux/uaccess.h>

#include "iob_class/iob_class_utils.h"
#include "iob_spi_master.h"

#define NUM_DEVICES 2

static int iob_spi_probe(struct platform_device *);
static int iob_spi_remove(struct platform_device *);

static ssize_t iob_spi_read(struct file *, char __user *, size_t, loff_t *);
static ssize_t iob_spi_write(struct file *, const char __user *, size_t,
                             loff_t *);
static loff_t iob_spi_llseek(struct file *, loff_t, int);
static int iob_spi_open(struct inode *, struct file *);
static int iob_spi_release(struct inode *, struct file *);

DEFINE_MUTEX(iob_spi_master_mutex);
struct spi_driver {
  dev_t devnum;
  struct class *class;
  struct list_head list;
};

static struct spi_driver spi_driver = {
    .devnum = 0,
    .class = NULL,
    .list = LIST_HEAD_INIT(spi_driver.list),
};

#include "iob_spi_master_sysfs_multi.h"

static const struct file_operations iob_spi_fops = {
    .owner = THIS_MODULE,
    .write = iob_spi_write,
    .read = iob_spi_read,
    .llseek = iob_spi_llseek,
    .open = iob_spi_open,
    .release = iob_spi_release,
};

static const struct of_device_id of_iob_spi_match[] = {
    {.compatible = "iobundle,spi0"},
    {},
};

static struct platform_driver iob_spi_driver = {
    .driver =
        {
            .name = "iob_spi",
            .owner = THIS_MODULE,
            .of_match_table = of_iob_spi_match,
        },
    .probe = iob_spi_probe,
    .remove = iob_spi_remove,
};

//
// Module init and exit functions
//
static int iob_spi_probe(struct platform_device *pdev) {
  struct resource *res;
  int result = 0;
  struct iob_data *iob_spi_data = NULL;

  mutex_lock(&iob_spi_master_mutex);
  if (MINOR(spi_driver.devnum) >= NUM_DEVICES) {
    pr_err("[Driver] %s: No more devices allowed!\n",
           IOB_SPI_MASTER_DRIVER_NAME);
    return -ENODEV;
  }
  mutex_unlock(&iob_spi_master_mutex);

  pr_info("[Driver] %s: probing.\n", IOB_SPI_MASTER_DRIVER_NAME);

  iob_spi_data = (struct iob_data *)devm_kzalloc(
      &pdev->dev, sizeof(struct iob_data), GFP_KERNEL);
  if (iob_spi_data == NULL) {
    pr_err("[Driver]: Failed to allocate memory for iob_spi_data\n");
    return -ENOMEM;
  }

  // add device to list
  mutex_lock(&iob_spi_master_mutex);
  list_add_tail(&iob_spi_data->list, &spi_driver.list);
  mutex_unlock(&iob_spi_master_mutex);

  // Get the I/O region base address
  res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
  if (!res) {
    pr_err("[Driver]: Failed to get I/O resource!\n");
    result = -ENODEV;
    goto r_get_resource;
  }

  // Request and map the I/O region
  iob_spi_data->regbase = devm_ioremap_resource(&pdev->dev, res);
  if (IS_ERR(iob_spi_data->regbase)) {
    result = PTR_ERR(iob_spi_data->regbase);
    goto r_ioremmap;
  }
  iob_spi_data->regsize = resource_size(res);

  cdev_init(&iob_spi_data->cdev, &iob_spi_fops);
  iob_spi_data->cdev.owner = THIS_MODULE;
  iob_spi_data->class = NULL;

  mutex_lock(&iob_spi_master_mutex);
  iob_spi_data->devnum = spi_driver.devnum;
  spi_driver.devnum =
      MKDEV(MAJOR(spi_driver.devnum), MINOR(spi_driver.devnum) + 1);
  mutex_unlock(&iob_spi_master_mutex);

  result = cdev_add(&iob_spi_data->cdev, iob_spi_data->devnum, 1);
  if (result) {
    pr_err("[Driver] %s: Char device registration failed!\n",
           IOB_SPI_MASTER_DRIVER_NAME);
    goto r_cdev_add;
  }

  iob_spi_data->device = device_create(
      spi_driver.class, NULL, iob_spi_data->devnum, iob_spi_data, "%s%d",
      IOB_SPI_MASTER_DRIVER_NAME, MINOR(iob_spi_data->devnum));
  if (iob_spi_data->device == NULL) {
    pr_err("[Driver] %s: Can not create device file!\n",
           IOB_SPI_MASTER_DRIVER_NAME);
    goto r_device;
  }

  // Associate iob_data to device
  pdev->dev.platform_data = iob_spi_data;             // pdev functions
  iob_spi_data->device->platform_data = iob_spi_data; // sysfs functions

  result = iob_spi_master_create_device_attr_files(iob_spi_data->device);
  if (result) {
    pr_err("Cannot create device attribute file......\n");
    goto r_dev_file;
  }

  dev_info(&pdev->dev, "initialized with %d\n", MINOR(iob_spi_data->devnum));
  goto r_ok;

r_dev_file:
  device_destroy(iob_spi_data->class, iob_spi_data->devnum);
  cdev_del(&(iob_spi_data->cdev));
r_device:
r_cdev_add:
  // iounmap is managed by devm
r_ioremmap:
r_get_resource:
r_ok:

  return result;
}

static int iob_spi_remove(struct platform_device *pdev) {
  struct iob_data *iob_spi_data = (struct iob_data *)pdev->dev.platform_data;
  iob_spi_master_remove_device_attr_files(iob_spi_data);
  cdev_del(&(iob_spi_data->cdev));

  // remove from list
  mutex_lock(&iob_spi_master_mutex);
  list_del(&iob_spi_data->list);
  mutex_unlock(&iob_spi_master_mutex);

  // Note: no need for iounmap, since we are using devm_ioremap_resource()
  dev_info(&pdev->dev, "remove.\n");

  return 0;
}

static int __init iob_spi_init(void) {
  int ret = 0;
  pr_info("[Driver] %s: initializing.\n", IOB_SPI_MASTER_DRIVER_NAME);

  // Allocate char device
  ret = alloc_chrdev_region(&spi_driver.devnum, 0, NUM_DEVICES,
                            IOB_SPI_MASTER_DRIVER_NAME);
  if (ret) {
    pr_err("[Driver] %s: Failed to allocate char device region\n",
           IOB_SPI_MASTER_DRIVER_NAME);
    goto r_exit;
  }

  // Create device class // todo: make a dummy driver just to create and own the
  // class: https://stackoverflow.com/a/16365027/8228163
  if ((spi_driver.class =
           class_create(THIS_MODULE, IOB_SPI_MASTER_DRIVER_CLASS)) == NULL) {
    printk("Device class can not be created!\n");
    goto r_alloc_region;
  }

  ret = platform_driver_register(&iob_spi_driver);
  if (ret < 0) {
    pr_err("[Driver] %s: Failed to register platform driver\n",
           IOB_SPI_MASTER_DRIVER_NAME);
    goto r_class;
  }

r_class:
  class_destroy(spi_driver.class);
r_alloc_region:
  unregister_chrdev_region(spi_driver.devnum, NUM_DEVICES);
r_exit:
  return ret;
}

static void __exit iob_spi_exit(void) {
  pr_info("[Driver] %s: exiting.\n", IOB_SPI_MASTER_DRIVER_NAME);

  mutex_lock(&iob_spi_master_mutex);
  spi_driver.devnum = MKDEV(MAJOR(spi_driver.devnum), 0);
  mutex_unlock(&iob_spi_master_mutex);

  platform_driver_unregister(&iob_spi_driver);

  unregister_chrdev_region(spi_driver.devnum, NUM_DEVICES);
}

//
// File operations
//

static int iob_spi_open(struct inode *inode, struct file *file) {
  struct iob_data *iob_spi_data = NULL;

  pr_info("[Driver] iob_spi device opened\n");

  if (!mutex_trylock(&iob_spi_master_mutex)) {
    pr_info("Another process is accessing the device\n");

    return -EBUSY;
  }

  // assign iob_spi_data to file private_data
  list_for_each_entry(iob_spi_data, &spi_driver.list, list) {
    if (iob_spi_data->devnum == inode->i_rdev) {
      file->private_data = iob_spi_data;
      return 0;
    }
  }

  return 0;
}

static int iob_spi_release(struct inode *inode, struct file *file) {
  pr_info("[Driver] iob_spi device closed\n");

  mutex_unlock(&iob_spi_master_mutex);

  return 0;
}

static ssize_t iob_spi_read(struct file *file, char __user *buf, size_t count,
                            loff_t *ppos) {
  int size = 0;
  u32 value = 0;
  struct iob_data *iob_spi_data = (struct iob_data *)file->private_data;

  /* read value from register */
  switch (*ppos) {
  case IOB_SPI_MASTER_FL_READY_ADDR:
    value =
        iob_data_read_reg(iob_spi_data->regbase, IOB_SPI_MASTER_FL_READY_ADDR,
                          IOB_SPI_MASTER_FL_READY_W);
    size = (IOB_SPI_MASTER_FL_READY_W >> 3); // bit to bytes
    pr_info("[Driver] %s: Read FL_READY: 0x%x\n", IOB_SPI_MASTER_DRIVER_NAME,
            value);
    break;
  case IOB_SPI_MASTER_FL_DATAOUT_ADDR:
    value =
        iob_data_read_reg(iob_spi_data->regbase, IOB_SPI_MASTER_FL_DATAOUT_ADDR,
                          IOB_SPI_MASTER_FL_DATAOUT_W);
    size = (IOB_SPI_MASTER_FL_DATAOUT_W >> 3); // bit to bytes
    pr_info("[Driver] %s: Read FL_DATAOUT: 0x%x\n", IOB_SPI_MASTER_DRIVER_NAME,
            value);
    break;
  case IOB_SPI_MASTER_VERSION_ADDR:
    value =
        iob_data_read_reg(iob_spi_data->regbase, IOB_SPI_MASTER_VERSION_ADDR,
                          IOB_SPI_MASTER_VERSION_W);
    size = (IOB_SPI_MASTER_VERSION_W >> 3); // bit to bytes
    pr_info("[Driver] %s: Read version 0x%x\n", IOB_SPI_MASTER_DRIVER_NAME,
            value);
    break;
  default:
    // invalid address - no bytes read
    return 0;
  }

  // Read min between count and REG_SIZE
  if (size > count)
    size = count;

  if (copy_to_user(buf, &value, size))
    return -EFAULT;

  return count;
}

static ssize_t iob_spi_write(struct file *file, const char __user *buf,
                             size_t count, loff_t *ppos) {
  int size = 0;
  u32 value = 0;
  struct iob_data *iob_spi_data = (struct iob_data *)file->private_data;

  switch (*ppos) {
  case IOB_SPI_MASTER_FL_RESET_ADDR:
    size = (IOB_SPI_MASTER_FL_RESET_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_spi_data->regbase, value,
                       IOB_SPI_MASTER_FL_RESET_ADDR, IOB_SPI_MASTER_FL_RESET_W);
    pr_info("[Driver] %s: FL_RESET iob_spi: 0x%x\n", IOB_SPI_MASTER_DRIVER_NAME,
            value);
    break;
  case IOB_SPI_MASTER_FL_DATAIN_ADDR:
    size = (IOB_SPI_MASTER_FL_DATAIN_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_spi_data->regbase, value,
                       IOB_SPI_MASTER_FL_DATAIN_ADDR,
                       IOB_SPI_MASTER_FL_DATAIN_W);
    pr_info("[Driver] %s: FL_DATAIN iob_spi: 0x%x\n",
            IOB_SPI_MASTER_DRIVER_NAME, value);
    break;
  case IOB_SPI_MASTER_FL_ADDRESS_ADDR:
    size = (IOB_SPI_MASTER_FL_ADDRESS_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_spi_data->regbase, value,
                       IOB_SPI_MASTER_FL_ADDRESS_ADDR,
                       IOB_SPI_MASTER_FL_ADDRESS_W);
    pr_info("[Driver] %s: FL_ADDRESS iob_spi: 0x%x\n",
            IOB_SPI_MASTER_DRIVER_NAME, value);
    break;
  case IOB_SPI_MASTER_FL_COMMAND_ADDR:
    size = (IOB_SPI_MASTER_FL_COMMAND_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_spi_data->regbase, value,
                       IOB_SPI_MASTER_FL_COMMAND_ADDR,
                       IOB_SPI_MASTER_FL_COMMAND_W);
    pr_info("[Driver] %s: FL_COMMAND iob_spi: 0x%x\n",
            IOB_SPI_MASTER_DRIVER_NAME, value);
    break;
  case IOB_SPI_MASTER_FL_COMMANDTP_ADDR:
    size = (IOB_SPI_MASTER_FL_COMMANDTP_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_spi_data->regbase, value,
                       IOB_SPI_MASTER_FL_COMMANDTP_ADDR,
                       IOB_SPI_MASTER_FL_COMMANDTP_W);
    pr_info("[Driver] %s: FL_COMMANDTP iob_spi: 0x%x\n",
            IOB_SPI_MASTER_DRIVER_NAME, value);
    break;
  case IOB_SPI_MASTER_FL_VALIDFLG_ADDR:
    size = (IOB_SPI_MASTER_FL_VALIDFLG_W >> 3); // bit to bytes
    if (read_user_data(buf, size, &value))
      return -EFAULT;
    iob_data_write_reg(iob_spi_data->regbase, value,
                       IOB_SPI_MASTER_FL_VALIDFLG_ADDR,
                       IOB_SPI_MASTER_FL_VALIDFLG_W);
    pr_info("[Driver] %s: FL_VALIDFLG iob_spi: 0x%x\n",
            IOB_SPI_MASTER_DRIVER_NAME, value);
    break;
  default:
    pr_info("[Driver] %s: Invalid write address 0x%x\n",
            IOB_SPI_MASTER_DRIVER_NAME, (unsigned int)*ppos);
    // invalid address - no bytes written
    return 0;
  }

  return count;
}

/* Custom lseek function
 * check: lseek(2) man page for whence modes
 */
static loff_t iob_spi_llseek(struct file *filp, loff_t offset, int whence) {
  loff_t new_pos = -1;
  struct iob_data *iob_spi_data = (struct iob_data *)filp->private_data;

  switch (whence) {
  case SEEK_SET:
    new_pos = offset;
    break;
  case SEEK_CUR:
    new_pos = filp->f_pos + offset;
    break;
  case SEEK_END:
    new_pos = (1 << IOB_SPI_MASTER_CSRS_CSRS_ADDR_W) + offset;
    break;
  default:
    return -EINVAL;
  }

  // Check for valid bounds
  if (new_pos < 0 || new_pos > iob_spi_data->regsize) {
    return -EINVAL;
  }

  // Update file position
  filp->f_pos = new_pos;

  return new_pos;
}

module_init(iob_spi_init);
module_exit(iob_spi_exit);

MODULE_LICENSE("Dual MIT/GPL");
MODULE_AUTHOR("IObundle");
MODULE_DESCRIPTION("IOb-SPI Drivers");
MODULE_VERSION("0.10");
