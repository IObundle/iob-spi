#!/usr/bin/env python3

import os

from iob_module import iob_module

# Submodules
from iob_utils import iob_utils
from iob_reg import iob_reg
from iob_reg_e import iob_reg_e
from iob_iobuf import iob_iobuf


class iob_spi_master(iob_module):
    name = "iob_spi_master"
    version = "V0.10"
    flows = "sim emb doc fpga"
    setup_dir = os.path.dirname(__file__)

    @classmethod
    def _create_submodules_list(cls):
        """Create submodules list with dependencies of this module"""
        super()._create_submodules_list(
            [
                {"interface": "iob_wire"},
                {"interface": "iob_s_port"},
                {"interface": "iob_s_portmap"},
                {"interface": "clk_en_rst_s_s_portmap"},
                {"interface": "clk_en_rst_s_port"},
                iob_utils,
                iob_reg,
                iob_reg_e,
                iob_iobuf,
            ]
        )

    @classmethod
    def _setup_confs(cls):
        super()._setup_confs(
            [
                # Macros
                # Parameters
                {
                    "name": "DATA_W",
                    "type": "P",
                    "val": "32",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Data bus width",
                },
                {
                    "name": "ADDR_W",
                    "type": "P",
                    "val": "`IOB_SPI_MASTER_SWREG_ADDR_W",
                    "min": "NA",
                    "max": "NA",
                    "descr": "Address bus width",
                },
                {
                    "name": "FL_ADDR_W",
                    "type": "P",
                    "val": "`IOB_SPI_MASTER_SWREG_ADDR_W",
                    "min": "NA",
                    "max": "NA",
                    "descr": "",
                },
                {
                    "name": "FL_WDATA_W",
                    "type": "P",
                    "val": "32",
                    "min": "NA",
                    "max": "NA",
                    "descr": "",
                },
                {
                    "name": "RUN_FLASH",
                    "type": "M",
                    "val": False,
                    "min": "NA",
                    "max": "NA",
                    "descr": "",
                },
            ]
        )

    @classmethod
    def _setup_ios(cls):
        cls.ios += [
            {"name": "iob_s_port", "descr": "CPU native interface", "ports": []},
            {
                "name": "iob_s_cache",
                "descr": "Cache interface.",
                "if_defined": "RUN_FLASH",
                "ports": [
                    {
                        "name": "avalid_cache",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "address_cache",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "wdata_cache",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "wstrb_cache",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "rdata_cache",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "rvalid_cache",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "ready_cache",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "",
                    },
                ],
            },
            {
                "name": "general",
                "descr": "GENERAL INTERFACE SIGNALS",
                "ports": [
                    {
                        "name": "clk_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "System clock input",
                    },
                    {
                        "name": "arst_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "System reset, asynchronous and active high",
                    },
                    {
                        "name": "cke_i",
                        "type": "I",
                        "n_bits": "1",
                        "descr": "System reset, asynchronous and active high",
                    },
                ],
            },
            {
                "name": "flash_if",
                "descr": "Flash memory interface signals",
                "ports": [
                    # {'name':'interrupt', 'type':'O', 'n_bits':'1', 'descr':'be done'},
                    {
                        "name": "SS",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "SCLK",
                        "type": "O",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "MISO",
                        "type": "IO",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "MOSI",
                        "type": "IO",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "WP_N",
                        "type": "IO",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "HOLD_N",
                        "type": "IO",
                        "n_bits": "1",
                        "descr": "",
                    },
                ],
            },
        ]

    @classmethod
    def _setup_regs(cls):
        cls.regs += [
            {
                "name": "uart",
                "descr": "UART software accessible registers.",
                "regs": [
                    {
                        "name": "FL_RESET",
                        "type": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "FL soft reset",
                    },
                    {
                        "name": "FL_DATAIN",
                        "type": "W",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "FL data_in",
                    },
                    {
                        "name": "FL_ADDRESS",
                        "type": "W",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "FL address",
                    },
                    {
                        "name": "FL_COMMAND",
                        "type": "W",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "FL command: [31:30]xipbit_en|[29:20]frame_struct|[19:16]dummy_cycles|[14:8]ndata_bits|[7:0]command",
                    },
                    {
                        "name": "FL_COMMANDTP",
                        "type": "W",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "FL command type: [31:30]spimode|[29:22]N/A|[21]fourbyteaddr|[20]dtr|[19:3]N/A|[2:0]commtype",
                    },
                    {
                        "name": "FL_VALIDFLG",
                        "type": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "FL valigflag",
                    },
                    {
                        "name": "FL_READY",
                        "type": "R",
                        "n_bits": 1,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "FL ready flag",
                    },
                    {
                        "name": "FL_DATAOUT",
                        "type": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                        "descr": "FL data_out",
                    },
                ],
            }
        ]

    @classmethod
    def _setup_block_groups(cls):
        cls.block_groups += []
