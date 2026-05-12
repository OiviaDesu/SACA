from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).with_name('analysis') / 'merge_classifier_runs.py'), run_name='__main__')
