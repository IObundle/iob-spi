import os

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
