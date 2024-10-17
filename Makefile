WARNFLAGS = -W -Wall -Werror
OPTFLAGS = -O3
DEBUGFLAGS = -ggdb3 -DDEBUG
CFLAGS += $(WARNFLAGS)
binaries = autostart/at_commander

ifdef DEBUG
	CFLAGS += $(DEBUGFLAGS)
else
	CFLAGS += $(OPTFLAGS)
endif

all: $(binaries)

luci:
	cp luci/myapp.lua /usr/lib/lua/luci/controller
	cp luci/myapp_status.htm /usr/lib/lua/luci/view
	@echo "Restart webinterface service or reboot to see changes under Status->My ci.App Satus"
clean:
	$(RM) *~ $(binaries) *.o