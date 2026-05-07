from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).with_name('export') / 'export_xgb_to_dart.py'), run_name='__main__')
