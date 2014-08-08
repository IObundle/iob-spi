#include <vpi_user.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

// Implements the system task
static int rw_calltf (char *userdata) {
  vpiHandle systfref, args_iter, argh;
  struct t_vpi_value argval;
  int value;
  static int sclk, ss, mosi, miso, rnw;
  int i;
  static int k,m; 
  // Obtain a handle to the argument list
  systfref = vpi_handle(vpiSysTfCall, NULL);
  args_iter = vpi_iterate(vpiArgument, systfref);

  // Grab the value of the first argument
  for(i=0; i<3;i++){
	  argh = vpi_scan(args_iter);
	  argval.format = vpiIntVal;
	  vpi_get_value(argh, &argval); 
	  value = argval.value.integer;
	  
	  // Increment the value and put it back as first argument
	  switch(i){
		case(0): //sclk
			vpi_printf("VPI clock received %2d\n", value);
			sclk=!value;
		  	argval.value.integer=sclk;
		break;
		case(1): //mosi
			vpi_printf("VPI mosi received %2d\n", value);
			
			if(sclk==0 && ss==0){
				if(m==0 || m==10|| m==15 )
					mosi=1;
				else
					mosi=0;
				
				m++;
			}else
				mosi=value;
			argval.value.integer=mosi;
		break;

		/*case(2): //miso
			vpi_printf("VPI miso received %2d\n", value);
			if(sclk==0 && ss==0)
				miso=random()%2;
			else
				miso=value;
			argval.value.integer=value;
		break;*/

		case(2): //ss
			vpi_printf("VPI ss received %2d\n\n", value);
			ss=value;
			if(sclk==0){
				if(k==1){
					rnw=mosi;
					ss=0;
				}
					if(k==9)
						ss=1;
					else if(k>9 && k<=17)
						ss=0;
					else if(k>17){
						ss=1;
						k=0;
					}
				k++;
			}	
				argval.value.integer=ss;						
		break;

	  }
	  vpi_put_value(argh, &argval, NULL, vpiNoDelay);
  }

  // Cleanup and return
  vpi_free_object(args_iter);
  return 0;

}

void rw_register()
{
      s_vpi_systf_data tf_data;

      tf_data.type      = vpiSysTask;
      tf_data.tfname    = "$vpi_rw";
      tf_data.calltf    = rw_calltf;
      tf_data.compiletf = 0;
      tf_data.sizetf    = 0;
      tf_data.user_data = 0;
      vpi_register_systf(&tf_data);
}

void (*vlog_startup_routines[])() = {
    rw_register,
    0
};
