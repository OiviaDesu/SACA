from pathlib import Path
import runpy

runpy.run_path(str(Path(__file__).with_name('data_ingestion') / 'prepare_gue_whisper_manifests.py'), run_name='__main__')
