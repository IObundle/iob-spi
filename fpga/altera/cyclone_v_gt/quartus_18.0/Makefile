VSRC := \
../../../top/spi_top.v \
../../../../rtl/src/spi_master.v \
../../../../rtl/src/spi_slave.v \

INCLUDE := ../../../../rtl/include/spi_defines.vh\

QXP := spi_master-spi_m.qxp spi_slave-spi_s.qxp

all:  $(QXP)

$(QXP): $(VSRC) $(INCLUDE) 
	quartus_map --read_settings_files=on --write_settings_files=off spi -c spi
	quartus_cdb --read_settings_files=off --write_settings_files=off spi -c spi --merge=on
	quartus_cdb spi -c spi --incremental_compilation_export=spi_master-spi_m.qxp --incremental_compilation_export_partition_name=spi_master:spi_m --incremental_compilation_export_post_synth=on --incremental_compilation_export_post_fit=off --incremental_compilation_export_routing=on --incremental_compilation_export_flatten=on
	quartus_cdb spi -c spi --incremental_compilation_export=spi_slave-spi_s.qxp --incremental_compilation_export_partition_name=spi_slave:spi_s --incremental_compilation_export_post_synth=on --incremental_compilation_export_post_fit=off --incremental_compilation_export_routing=on --incremental_compilation_export_flatten=on

clean: 
	quartus_sh --clean spi
	@rm -f *.qarlog *.qws *.qxp *~
	@rm -rf db incremental_db output_files

.PHONY: all clean
