import os, shutil

from iob_module import iob_module


class N25Qxxx(iob_module):
    name = "N25Qxxx"
    version = "V0.10"
    flows = "sim"
    setup_dir = os.path.dirname(__file__)

    @classmethod
    def _create_submodules_list(cls):
        """Create submodules list with dependencies of this module"""
        super()._create_submodules_list([])

    @classmethod
    def _post_setup(cls):
        super()._post_setup()
        dst = f"{cls.build_dir}/hardware/simulation"
        src_file = f"{__class__.build_dir}/hardware/simulation/src/mem_Q256.vmf"
        shutil.copy2(src_file, dst)
        src_file = f"{__class__.build_dir}/hardware/simulation/src/sfdp.vmf"
        shutil.copy2(src_file, dst)
