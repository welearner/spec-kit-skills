.PHONY: sync check clean

sync:
	./scripts/sync.sh

check:
	./scripts/check.sh

clean:
	rm -rf skills UPSTREAM.json THIRD_PARTY_NOTICES/spec-kit-LICENSE
