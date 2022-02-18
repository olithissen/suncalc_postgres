EXTENSION = suncalc
MODULE_big = suncalc
DATA = suncalc--0.0.1.sql
REGRESS = suncalc_test
OBJS = suncalc.o 
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
$(OBJS): CFLAGS += $(PERMIT_DECLARATION_AFTER_STATEMENT)