# Makefile to generate parameter files from templates

SOURCE_DIR = ../src/oracledb

all: $(SOURCE_DIR)/connect_params.py $(SOURCE_DIR)/pool_params.py

$(SOURCE_DIR)/connect_params.py: fields.cfg connect_params_template.py
	python build_from_template.py connect_params

$(SOURCE_DIR)/pool_params.py: fields.cfg pool_params_template.py
	python build_from_template.py pool_params

