#   Copyright (C) 2016 Juan Manuel Torres Palma <j.m.torrespalma@gmail.com>
#
#   This file is part of OGWG, the Oldie Goldie Website Generator.
#
#   OGWG is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3, or (at your option)
#   any later version.
#
#   OGWG is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with OGWG.  If not, see <http://www.gnu.org/licenses/>.

# This makefile is the main building tool and takes care of every single action
# taken to build the website. It should be only used after ./configure has
# tested that all the required tools are installed.
#hunspell and formatting to 72 cols

# List of used tools, useful for portability issues
# I'm using GNU tools, so it may lead to portability issues.
# Modify this variables and add your options if you are using different
# versions.
GREP := grep
SED := sed
AWK := awk
SORT := sort
CUT := cut
HEAD := head
SHELL := /bin/bash

# Variables related to the project
DEST_REMOTE := ../www
DEST_DIR := ../install
DEST_POSTS_DIR := $(DEST_DIR)/posts
DEST_EXTRA_DIR := $(DEST_DIR)/extra
EXTRA_DIR := ./extra
POSTS_DIR := ./posts
MAIN_DIR := ./main

INC := $(wildcard include/*.prehtml)

# Variables related to blog and posts.
RAW_POSTS := $(wildcard $(POSTS_DIR)/*.prehtml)
FORMATTED_POSTS := $(RAW_POSTS:.prehtml=.html)
SORT_POSTS_LIST := $(POSTS_DIR)/posts-list.txt
LATEST_POSTS := $(POSTS_DIR)/latest-posts.txt

# Main files explicit on the top of every page.
GEN_MAIN := $(MAIN_DIR)/archive.prehtml $(MAIN_DIR)/blog.prehtml \
		$(MAIN_DIR)/cv.prehtml
RAW_MAIN := $(wildcard $(MAIN_DIR)/*.prehtml) $(GEN_MAIN)
FORMATTED_MAIN := $(RAW_MAIN:.prehtml=.html)


# Installation variables.
MAIN_TARG := $(subst $(MAIN_DIR), $(DEST_DIR), $(FORMATTED_MAIN))
POSTS_TARG := $(subst $(POSTS_DIR), $(DEST_POSTS_DIR), $(FORMATTED_POSTS))
CSS_MAIN := $(DEST_DIR)/style.css
CSS_POSTS := $(DEST_POSTS_DIR)/style.css
EXTRA_FILES := $(wildcard $(EXTRA_DIR)/*)
EXTRA_TARG := $(subst $(EXTRA_DIR), $(DEST_EXTRA_DIR), $(EXTRA_FILES))


# Building rules

all: $(FORMATTED_MAIN) $(FORMATTED_POSTS)

local-install: all $(MAIN_TARG) $(POSTS_TARG) $(CSS_POSTS) $(CSS_MAIN)\
	$(EXTRA_TARG)

install: local-install
	rsync -rtv $(DEST_DIR)/ $(DEST_REMOTE)

# Final formatting rule, required by every single served page.
%.html: %.prehtml $(INC)
	@echo -n "Creating html file: $@..."
	@if [ $$(dirname $@) = $$(basename $(POSTS_DIR)) ]; then\
		$(SED) 's/href="/href="..\//g' include/header.prehtml >\
			include/headersub.prehtml; \
	else\
		cp include/header.prehtml include/headersub.prehtml;\
	fi
	@$(SED) '/<html/ r include/head.prehtml' $< |\
	$(SED) '/<body>/ r include/headersub.prehtml' |\
	$(AWK) '/<\/body>/{fl=$$0; while(getline<"include/footer.prehtml")\
	{print}; print fl; next}1' > $@
	@$(RM) include/headersub.prehtml
	@echo "done"


# Especific rules for generated files
$(MAIN_DIR)/blog.prehtml: $(RAW_POSTS) $(LATEST_POSTS)
	@echo -n "Generating $@..."
	@cp include/skeleton.prehtml $@
	@FILES=$$(tac $(LATEST_POSTS)); \
	PF=$$(basename $(DEST_POSTS_DIR)); \
	for f in $$FILES; \
	do \
		NAM=$$(basename $$f | $(SED) 's/pre//g'); \
		$(SED) -n '/<div class/,/<\/p>/p' $$f | $(SED) '$$ a \\t</div>' | \
		$(SED) "$$ a \\\\t<a href=\"$$PF\/$$NAM\">Read more.<\/a>" | \
		$(SED) '$$ a \\t<hr>' | \
		$(SED) -i '/<body>/ r /dev/stdin' $@; \
	done
	@echo "done"

$(MAIN_DIR)/archive.prehtml: $(RAW_POSTS) $(SORT_POSTS_LIST)
	@echo -n "Generating $@..."
	@rm -f $@ tmp.txt
	@touch tmp.txt
	@cp include/skeleton.prehtml $@
	@cut -d: -f2 $(SORT_POSTS_LIST) | uniq | \
	while read -r DATE; \
	do \
		POSTS=$$(grep $$DATE $(SORT_POSTS_LIST) | cut -d: -f1);\
		PF=$$(basename $(DEST_POSTS_DIR)); \
		echo "<h3>$$DATE</h3>" >> tmp.txt; \
		for P in $$POSTS; \
		do \
			TITLE=$$($(GREP) '<h2>' $$P | \
			$(SED) -e 's/<\/\?h2>//g' -e 's/\t//g'); \
			S_P=$$(basename $$P | $(SED) 's/.prehtml/.html/g') ; \
			echo "<a href=$$PF/$$S_P>$$TITLE.</a>" >> tmp.txt; \
		done; \
		echo "<hr>" >> tmp.txt; \
	done
	@$(AWK) '{ print "\t"$$0 }' tmp.txt | \
	$(SED) -i '/<body>/ r /dev/stdin' $@
	@$(RM) tmp.txt
	@echo "done"

$(MAIN_DIR)/cv.prehtml: cv.tex
	@echo -n "Generating $@..."
	@TDIR=$$(mktemp -d); \
	latex2html -dir $$TDIR -split 0 -info 0 -lcase_tags -no_navigation \
	-no_subdir -style style.css $< > /dev/null 2>&1; \
	mv $$TDIR/cv.html tmp.prehtml; $(RM) -r $$TDIR
	@$(SED) -n '/<body >/,/<\/body>/p' tmp.prehtml | \
	$(SED) -e '1 i <!DOCTYPE html>\n<html lang="en">' \
	-e '$$ i <\/html>' -e 's/<body >/<body>/g' > $@
	@$(RM) tmp.prehtml
	@echo "done"

# List with all posts sorted by date, newest to oldest.
$(SORT_POSTS_LIST): $(RAW_POSTS)
	@echo -n "Generating $@..."
	@$(GREP) -n -E '[0-9]{4}/[0-9]{2}/[0-9]{2}' $(RAW_POSTS) |\
	$(SED) -e 's/<\/\?small>//g' | $(SED) 's/[ \t]//g' | cut -f1,3 -d':' |\
	$(SORT) -k2 -t: | tac > $@
	@echo "done"

$(LATEST_POSTS): $(SORT_POSTS_LIST)
	@echo -n "Generating $@..."
	@$(HEAD) -5 $< | cut -f1 -d: > $@
	@echo "done"



# Rules related to local installation.
$(DEST_DIR)/%.html: $(MAIN_DIR)/%.html
	@echo -n "Installing $@..."
	@cp $< $@
	@echo "done"

$(DEST_POSTS_DIR)/%.html: $(POSTS_DIR)/%.html
	@if [ ! -d "$(DEST_POSTS_DIR)" ]; then mkdir -p $(DEST_POSTS_DIR); fi
	@echo -n "Installing $@..."
	@cp $< $@
	@echo "done"

$(CSS_MAIN): style.css
	@echo -n "Copying $@..."
	@cp $< $@
	@echo "done"

$(CSS_POSTS): style.css
	@echo -n "Copying $@..."
	@cp $< $@
	@echo "done"

$(DEST_EXTRA_DIR)/%: $(EXTRA_DIR)/%
	@if [ ! -d "$(DEST_EXTRA_DIR)" ]; then mkdir -p $(DEST_EXTRA_DIR); fi
	@echo -n "Copying $@..."
	@cp $< $@
	@echo "done"


.PHONY: clean mrproper uninstall debug

# Cleans html files.
clean:
	@echo -n 'Cleaning builds...'
	@$(RM) -r $(FORMATTED_MAIN) $(FORMATTED_POSTS)
	@echo "done"

# Cleans generated files *.prehtml and lists.
mrproper: clean
	@echo -n 'Deleting everything...'
	@$(RM) -r $(GEN_MAIN) $(SORT_POSTS_LIST) $(LATEST_POSTS)
	@echo "done"

# Wipe out an installation folder.
uninstall:
	@echo -n 'Uninstalling...'
	@$(RM) -r $(MAIN_TARG) $(POSTS_TARG) $(CSS_MAIN) $(CSS_POSTS)
	@echo "done"

debug:
	@echo $(MAIN_TARG)
	@echo $(POSTS_TARG)
