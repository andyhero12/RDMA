CC=gcc
CFLAGS=-c -Wall -Wunused-variable
LDFLAGS=-L$(LIBMEMCACHED_HOME)/lib
LIBS=-lmemcached -lpthread -lm
INCLUDES=-I$(LIBMEMCACHED_HOME)/include
LAT_SOURCES=ohb_memlat.c
NBLAT_SOURCES=ohb_memlat_nb.c
HYB_SOURCES=ohb_memhybrid.c
LAT_OBJECTS=$(LAT_SOURCES:.c=.o)
NBLAT_OBJECTS=$(NBLAT_SOURCES:.c=.o)
HYB_OBJECTS=$(HYB_SOURCES:.c=.o)
LAT_EXECUTABLE=ohb_memlat
NBLAT_EXECUTABLE=ohb_memlat_nb
HYB_EXECUTABLE=ohb_memhybrid
INSTALL_DIR=../target

MV = mv
LS = ls -ltr
RM = rm -f
MKDIR = mkdir -p

ifndef LIBMEMCACHED_HOME
$(error LIBMEMCACHED_HOME is not set. Run export LIBMEMCACHED_HOME=<LIBMEMCACHED-INSTALL-PATH>)
endif

.PHONY: all lat nblat hyb

all: lat nblat hyb

install: all 
	@$(MKDIR) $(INSTALL_DIR)
	@$(MV) -t $(INSTALL_DIR) $(LAT_EXECUTABLE) $(NBLAT_EXECUTABLE) $(HYB_EXECUTABLE)
	@$(LS) $(INSTALL_DIR)

lat: $(LAT_EXECUTABLE)
	
nblat: $(NBLAT_EXECUTABLE)

hyb: $(HYB_EXECUTABLE)

$(LAT_EXECUTABLE): $(LAT_OBJECTS) 
	$(CC) $(LDFLAGS) $^ -o $@ $(LIBS)

$(NBLAT_EXECUTABLE): $(NBLAT_OBJECTS) 
	$(CC) $(LDFLAGS) $^ -o $@ $(LIBS)

$(HYB_EXECUTABLE): $(HYB_OBJECTS) 
	$(CC) $(LDFLAGS) $^ -o $@ $(LIBS)

.c.o:
	$(CC) $(CFLAGS) $(INCLUDES) $< -o $@

clean:
	@$(RM) *o $(LAT_EXECUTABLE) $(NBLAT_EXECUTABLE) $(HYB_EXECUTABLE) 
