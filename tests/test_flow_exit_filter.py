"""Compatibility entry point for the expanded five-IP/background filter suite."""
import pathlib
import runpy

if __name__ == '__main__':
    runpy.run_path(str(pathlib.Path(__file__).with_name('test_flow_pool.py')), run_name='__main__')
