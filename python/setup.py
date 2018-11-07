import sys
from cx_Freeze import setup, Executable

build_exe_options = {"packages": ["numpy"]}

base = None

setup(  name = "VRDigitizer_helper",
        version = "0.1",
        description = "VRDigitizer helper",
        options = {"build_exe" : build_exe_options},
        executables = [Executable("VRDigitizer_helper.py", base=base)])