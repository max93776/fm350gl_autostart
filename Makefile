WARNFLAGS = -W -Wall -Werror
OPTFLAGS = -O3
DEBUGFLAGS = -ggdb3 -DDEBUG
CFLAGS += $(WARNFLAGS)
binaries = at_commander

ifdef DEBUG
	CFLAGS += $(DEBUGFLAGS)
else
	CFLAGS += $(OPTFLAGS)
endif

all: $(binaries)

clean:
	$(RM) *~ $(binaries) *.o