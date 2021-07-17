NAMES := paper velocity
ARTIFACTS := $(NAMES:%=%-artifact)
BUILDERS := $(NAMES:%=%-build)

.PHONY: all $(ARTIFACTS) $(BUILDERS)

all: $(ARTIFACTS)

paper-artifact: paper-build

velocity-artifact: velocity-build
