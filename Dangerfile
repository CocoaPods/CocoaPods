# Don't let testing shortcuts get into master by accident

fail("fdescribe left in tests") if `grep -r fdescribe spec/`.length > 1
fail("fit left in tests") if `grep -r "fit spec/ `.length > 1
