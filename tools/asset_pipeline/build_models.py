"""Stable entry point for the detailed Blender asset generator."""
import os, runpy
runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build_detailed_models.py'), run_name='__main__')
