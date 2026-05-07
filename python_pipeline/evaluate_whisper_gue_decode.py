from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).with_name('analysis') / 'evaluate_whisper_gue_decode.py'), run_name='__main__')
