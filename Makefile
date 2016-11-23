ifdef CC_OQS
	CC=$(CC_OQS)
else
	CC=cc
endif

AR=ar rcs
CURL=curl
RANLIB=ranlib
LN=ln -s

CFLAGS= -O3 -std=gnu11 -Wpedantic -Wall -Wextra -DCONSTANT_TIME
LDFLAGS=-lm
INCLUDES=-Iinclude

ifdef ARCH
	CFLAGS += $(ARCH)
else
	CFLAGS += -march=x86-64
endif

ifdef AES_NI
	AES_NI_LOCAL=$(AES_NI)
else
	AES_NI_LOCAL=1
endif
ifeq ($(AES_NI_LOCAL),1)
CFLAGS += -maes -msse2
else
CFLAGS += -DAES_DISABLE_NI
endif

ifdef USE_OPENSSL
	CFLAGS += -DUSE_OPENSSL
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		OPENSSL_DIR=/usr
	endif
	ifeq ($(UNAME_S),Darwin)
		OPENSSL_DIR=/usr/local/opt/openssl
	endif
	INCLUDES += -I$(OPENSSL_DIR)/include
	LDFLAGS += -L$(OPENSSL_DIR)/lib -lcrypto
endif

.PHONY: all check clean prettyprint

all: links lib tests

objs/%.o: src/%.c
	@mkdir -p $(@D)
	$(CC) -c  $(CFLAGS) $(INCLUDES) $< -o $@

links:
	rm -rf include/oqs
	mkdir -p include/oqs
	$(LN) ../../src/aes/aes.h include/oqs
	$(LN) ../../src/kex/kex.h include/oqs
	$(LN) ../../src/kex_rlwe_bcns15/kex_rlwe_bcns15.h include/oqs
	$(LN) ../../src/kex_rlwe_newhope/kex_rlwe_newhope.h include/oqs
	$(LN) ../../src/kex_rlwe_msrln16/kex_rlwe_msrln16.h include/oqs
	$(LN) ../../src/kex_lwe_frodo/kex_lwe_frodo.h include/oqs
	$(LN) ../../src/rand/rand.h include/oqs
	$(LN) ../../src/rand_urandom_chacha20/rand_urandom_chacha20.h include/oqs
	$(LN) ../../src/rand_urandom_aesctr/rand_urandom_aesctr.h include/oqs
	$(LN) ../../src/common/common.h include/oqs

# RAND_URANDOM_CHACHA
RAND_URANDOM_CHACHA_OBJS :=  $(addprefix objs/rand_urandom_chacha20/, rand_urandom_chacha20.o)
$(RAND_URANDOM_CHACHA_OBJS): src/rand_urandom_chacha20/rand_urandom_chacha20.h

# RAND_URANDOM_AESCTR
RAND_URANDOM_AESCTR_OBJS :=  $(addprefix objs/rand_urandom_aesctr/, rand_urandom_aesctr.o)
$(RAND_URANDOM_AESCTR_OBJS): src/rand_urandom_aesctr/rand_urandom_aesctr.h

# RAND
objs/rand/rand.o: src/rand/rand.h

# KEX_RLWE_BCNS15
KEX_RLWE_BCNS15_OBJS := $(addprefix objs/kex_rlwe_bcns15/, fft.o kex_rlwe_bcns15.o rlwe.o rlwe_kex.o)
KEX_RLWE_BCNS15_HEADERS := $(addprefix src/kex_rlwe_bcns15/, kex_rlwe_bcns15.h local.h rlwe_a.h rlwe_table.h)
$(KEX_RLWE_BCNS15_OBJS): $(KEX_RLWE_BCNS15_HEADERS)

# KEX_NEWHOPE
KEX_RLWE_NEWHOPE_OBJS := $(addprefix objs/kex_rlwe_newhope/, kex_rlwe_newhope.o)
KEX_RLWE_NEWHOPE_HEADERS := $(addprefix src/kex_rlwe_newhope/, kex_rlwe_newhope.h fips202.c newhope.c params.h poly.c precomp.c)
$(KEX_RLWE_NEWHOPE_OBJS): $(KEX_RLWE_NEWHOPE_HEADERS)

# KEX_RLWE_MSRLN16
KEX_RLWE_MSRLN16_OBJS := $(addprefix objs/kex_rlwe_msrln16/, kex_rlwe_msrln16.o LatticeCrypto_kex.o ntt_constants.o)
KEX_RLWE_MSRLN16_HEADERS := $(addprefix src/kex_rlwe_msrln16/, LatticeCrypto.h LatticeCrypto_priv.h kex_rlwe_msrln16.h )
$(KEX_RLWE_MSRLN16_OBJS): $(KEX_RLWE_MSRLN16_HEADERS)

# KEX_LWE_FRODO
KEX_LWE_FRODO_OBJS := $(addprefix objs/kex_lwe_frodo/, lwe.o kex_lwe_frodo.o lwe_noise.o)
KEX_LWE_FRODO_HEADERS := $(addprefix src/kex_lwe_frodo/, kex_lwe_frodo.h local.h)
$(KEX_LWE_FRODO_OBJS): $(KEX_LWE_FRODO_HEADERS)

# AES
AES_OBJS := $(addprefix objs/aes/, aes.o aes_c.o aes_ni.o)
AES_HEADERS := $(addprefix src/aes/, aes.h)
$(AES_OBJS): $(AES_HEADERS)

#COMMON
COMMON_OBJS := $(addprefix objs/common/, common.o)
COMMON_HEADERS := $(addprefix src/common/, common.h)
$(COMMON_OBJS): $(COMMON_HEADERS)


# KEX
objs/kex/kex.o: src/kex/kex.h

# LIB


RAND_OBJS := $(RAND_URANDOM_AESCTR_OBJS) $(RAND_URANDOM_CHACHA_OBJS)

lib: $(RAND_OBJS) $(KEX_RLWE_BCNS15_OBJS) $(KEX_RLWE_NEWHOPE_OBJS) $(KEX_LWE_FRODO_OBJS) $(KEX_RLWE_MSRLN16_OBJS) objs/rand/rand.o objs/kex/kex.o $(AES_OBJS) $(COMMON_OBJS)
	rm -f liboqs.a
	$(AR) liboqs.a $^
	$(RANLIB) liboqs.a

tests: lib src/rand/test_rand.c src/kex/test_kex.c src/aes/test_aes.c src/ds_benchmark.h
	$(CC) $(CFLAGS) $(INCLUDES) -L. src/rand/test_rand.c -loqs $(LDFLAGS) -o test_rand 
	$(CC) $(CFLAGS) $(INCLUDES) -L. src/kex/test_kex.c -loqs $(LDFLAGS) -o test_kex
	$(CC) $(CFLAGS) $(INCLUDES) -L. src/aes/test_aes.c -loqs $(LDFLAGS) -o test_aes

docs: links
	doxygen

check: links tests
	./test_kex
	./test_rand
	./test_aes

clean:
	rm -rf docs objs include
	rm -f test_rand test_kex test_aes liboqs.a
	find . -name .DS_Store -type f -delete

prettyprint:
	astyle --style=java --indent=tab --pad-header --pad-oper --align-pointer=name --align-reference=name --suffix=none src/*.h src/*/*.h src/*/*.c
