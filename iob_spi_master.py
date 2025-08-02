# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params_dict):
    attributes_dict = {
        "generate_hw": True,
        "confs": [
            {
                "name": "RUN_FLASH",
                "descr": "",
                "type": "M",
                "val": False,
                "min": "NA",
                "max": "NA",
            },
            # Parameters
            {
                "name": "DATA_W",
                "descr": "Data bus width",
                "type": "P",
                "val": "32",
                "min": "NA",
                "max": "NA",
            },
            {
                "name": "ADDR_W",
                "descr": "Address bus width",
                "type": "P",
                "val": "`IOB_SPI_MASTER_CSRS_ADDR_W",
                "min": "NA",
                "max": "NA",
            },
            {
                "name": "FL_ADDR_W",
                "descr": "",
                "type": "P",
                "val": "`IOB_SPI_MASTER_CSRS_ADDR_W",
                "min": "NA",
                "max": "NA",
            },
            {
                "name": "FL_WDATA_W",
                "descr": "",
                "type": "P",
                "val": "32",
                "min": "NA",
                "max": "NA",
            },
        ],
        "ports": [
            {
                "name": "clk_en_rst_s",
                "descr": "Clock, clock enable and reset",
                "signals": {
                    "type": "iob_clk",
                },
            },
            {
                "name": "iob_s",
                "descr": "CPU native interface",
                "signals": {
                    "type": "iob",
                },
            },
            {
                "name": "cache_iob_s",
                "descr": "Cache interface.",
                "if_defined": "RUN_FLASH",
                "signals": {
                    "type": "iob",
                    "prefix": "cache_",
                },
            },
            {
                "name": "flash_io",
                "descr": "Flash memory interface signals",
                "signals": [
                    # {'name':'interrupt_o', 'n_bits':'1', 'descr':'be done'},
                    {
                        "name": "ss_o",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "sclk_o",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "miso_io",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "mosi_io",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "wp_n_io",
                        "n_bits": "1",
                        "descr": "",
                    },
                    {
                        "name": "hold_n_io",
                        "n_bits": "1",
                        "descr": "",
                    },
                ],
            },
        ],
        "wires": [
            # Wires for CSRs
            {
                "name": "fl_reset",
                "descr": "",
                "signals": [
                    {"name": "fl_reset_wr", "width": 1},
                ],
            },
            {
                "name": "fl_datain",
                "descr": "",
                "signals": [
                    {"name": "fl_datain_wr", "width": 32},
                ],
            },
            {
                "name": "fl_address",
                "descr": "",
                "signals": [
                    {"name": "fl_address_wr", "width": 32},
                ],
            },
            {
                "name": "fl_command",
                "descr": "",
                "signals": [
                    {"name": "fl_command_wr", "width": 32},
                ],
            },
            {
                "name": "fl_commandtp",
                "descr": "",
                "signals": [
                    {"name": "fl_commandtp_wr", "width": 32},
                ],
            },
            {
                "name": "fl_validflg",
                "descr": "",
                "signals": [
                    {"name": "fl_validflg_wr", "width": 1},
                ],
            },
            {
                "name": "fl_ready",
                "descr": "",
                "signals": [
                    {"name": "fl_ready_rd", "width": 1},
                ],
            },
            {
                "name": "fl_dataout",
                "descr": "",
                "signals": [
                    {"name": "fl_dataout_rd", "width": 32},
                ],
            },
        ],
        "subblocks": [
            {
                "core_name": "iob_csrs",
                "instance_name": "iob_csrs",
                "instance_description": "Control/Status Registers",
                "csrs": [
                    {
                        "name": "fl_reset",
                        "descr": "FL soft reset",
                        "mode": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                    },
                    {
                        "name": "fl_datain",
                        "descr": "FL data_in",
                        "mode": "W",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                    },
                    {
                        "name": "fl_address",
                        "descr": "FL address",
                        "mode": "W",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                    },
                    {
                        "name": "fl_command",
                        "descr": "FL command: [31:30]xipbit_en|[29:20]frame_struct|[19:16]dummy_cycles|[14:8]ndata_bits|[7:0]command",
                        "mode": "W",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                    },
                    {
                        "name": "fl_commandtp",
                        "descr": "FL command type: [31:30]spimode|[29:22]N/A|[21]fourbyteaddr|[20]dtr|[19:3]N/A|[2:0]commtype",
                        "mode": "W",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                    },
                    {
                        "name": "fl_validflg",
                        "descr": "FL valigflag",
                        "mode": "W",
                        "n_bits": 1,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                    },
                    {
                        "name": "fl_ready",
                        "descr": "FL ready flag",
                        "mode": "R",
                        "n_bits": 1,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                    },
                    {
                        "name": "fl_dataout",
                        "descr": "FL data_out",
                        "mode": "R",
                        "n_bits": 32,
                        "rst_val": 0,
                        "log2n_items": 0,
                        "autoreg": True,
                    },
                ],
                "csr_if": "iob",
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    # 'control_if_m' port connected automatically
                    # Register interfaces
                    "fl_reset_o": "fl_reset",
                    "fl_datain_o": "fl_datain",
                    "fl_address_o": "fl_address",
                    "fl_command_o": "fl_command",
                    "fl_commandtp_o": "fl_commandtp",
                    "fl_validflg_o": "fl_validflg",
                    "fl_ready_i": "fl_ready",
                    "fl_dataout_i": "fl_dataout",
                },
            },
            {
                "core_name": "iob_iobuf",
                "instantiate": False,
            },
        ],
        "snippets": [
            {
                "verilog_code": """
""",
            },
        ],
    }

    return attributes_dict
