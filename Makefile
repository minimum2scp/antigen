SHELL     ?= sh
PREFIX    ?= /usr/local

CRAM_OPTS ?= -v

PROJECT   ?= $(CURDIR)
BIN       ?= ${PROJECT}/bin
SRC       ?= ${PROJECT}/src
TESTS     ?= ${PROJECT}/tests
TOOLS     ?= ${PROJECT}/tools
TEST      ?= ${PROJECT}/tests

ZSH_VERSION     ?= zsh-5.3
CONTAINER_ROOT  ?= /antigen
USE_CONTAINER   ?= docker
CONTAINER_IMAGE ?= desyncr/zsh-docker-

TARGET     ?= ${BIN}/antigen.zsh
SRC        ?= ${SRC}
EXTENSIONS ?= ${SRC}/ext/ext.zsh ${SRC}/ext/defer.zsh ${SRC}/ext/lock.zsh ${SRC}/ext/cache.zsh
GLOB       ?= ${SRC}/boot.zsh ${SRC}/antigen.zsh $(sort $(wildcard ${PWD}/src/helpers/*.zsh)) \
        ${SRC}/lib/*.zsh $(sort $(wildcard ${PWD}/src/commands/*.zsh)) ${EXTENSIONS} \
        ${SRC}/_antigen

VERSION      ?= develop
VERSION_FILE  = ${PROJECT}/VERSION

BANNER_SEP    =$(shell printf '%*s' 70 | tr ' ' '\#')
BANNER_TEXT   =This file was autogenerated by \`make\`. Do not edit it directly!
BANNER        =${BANNER_SEP}\n\# ${BANNER_TEXT}\n${BANNER_SEP}\n

define ised
	sed $(1) $(2) > "$(2).1"
	mv "$(2).1" "$(2)"
endef

.PHONY: itests tests install all

build:
	@echo Building Antigen...
	@printf "${BANNER}" > ${BIN}/antigen.zsh
	@for src in ${GLOB}; do echo "----> $$src"; cat "$$src" >> ${TARGET}; done
	@echo "${VERSION}" > ${VERSION_FILE}
	@$(call ised,"s/{{ANTIGEN_VERSION}}/$$(cat ${VERSION_FILE})/",${TARGET})
	@echo Done.
	@ls -sh ${TARGET}

release:
	git checkout develop
	${MAKE} build tests
	git checkout -b release/${VERSION}
	# Update changelog
	${EDITOR} CHANGELOG.md
	# Build release commit
	git add CHANGELOG.md ${VERSION_FILE} README.mkd ${TARGET}
	git commit -S -m "Build release ${VERSION}"

publish:
	git push origin release/${VERSION}
	# Merge release branch into develop before deploying

deploy:
	git checkout develop
	git tag -m "Build release ${VERSION}" -s ${VERSION}
	git archive --output=${VERSION}.tar.gz --prefix=antigen-$$(echo ${VERSION}|sed s/v//)/ ${VERSION}
	zcat ${VERSION}.tar.gz | gpg --armor --detach-sign >${VERSION}.tar.gz.sign
	# Verify signature
	zcat ${VERSION}.tar.gz | gpg --verify ${VERSION}.tar.gz.sign -
	# Push upstream
	git push upstream ${VERSION}

.container:
ifeq (${USE_CONTAINER}, docker)
	@docker run --rm --privileged=true -it -v ${PROJECT}:/antigen ${CONTAINER_IMAGE}${ZSH_VERSION} $(shell echo "${COMMAND}" | sed "s|${PROJECT}|${CONTAINER_ROOT}|g")
else ifeq (${USE_CONTAINER}, no)
	${COMMAND}
endif

info:
	@${MAKE} .container COMMAND="sh -c 'cat ${PROJECT}/VERSION; zsh --version; git --version; env'"

itests:
	@${MAKE} tests CRAM_OPTS=-i

tests:
	@${MAKE} .container COMMAND="sh -c 'ZDOTDIR=${TESTS} ANTIGEN=${PROJECT} cram ${CRAM_OPTS} --shell=zsh ${TEST}'"

stats:
	@${MAKE} .container COMMAND="${TOOLS}/stats --zsh zsh --antigen ${PROJECT}"

install:
	mkdir -p ${PREFIX}/share && cp ${TARGET} ${PREFIX}/share/antigen.zsh

clean:
	rm -f ${PREFIX}/share/antigen.zsh

install-deps:
	sudo pip install cram=='0.6.*'

all: clean build install
