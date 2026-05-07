from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).with_name('training') / '02_finetune_whisper.py'), run_name='__main__')
