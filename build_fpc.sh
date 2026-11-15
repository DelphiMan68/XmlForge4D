#!/bin/sh
# Builds and runs the XmlForge4D test suite, examples and benchmarks with Free Pascal.
# Usage:  ./build_fpc.sh [test|bench|examples|all]      (default: test)
set -e
cd "$(dirname "$0")"
FPC=${FPC:-fpc}
mkdir -p build/units build/bin
FLAGS="-Mdelphiunicode -Fusrc -Futests -Fubenchmarks -FUbuild/units -FEbuild/bin -O2 -vewnh"

what=${1:-test}

build_tests() {
  $FPC $FLAGS tests/XmlForge4DTests.lpr
  ./build/bin/XmlForge4DTests
}
build_bench() {
  $FPC $FLAGS benchmarks/XmlForge4DBench.lpr
  ./build/bin/XmlForge4DBench "${2:-1}"
}
build_examples() {
  for e in ExampleXmlJson ExampleDomXPath ExampleSax; do
    $FPC $FLAGS examples/FreePascal/$e.lpr
    echo "---- $e ----"
    ./build/bin/$e
  done
}

case "$what" in
  test) build_tests ;;
  bench) build_bench "$@" ;;
  examples) build_examples ;;
  all) build_tests; build_examples ;;
  *) echo "usage: $0 [test|bench|examples|all]"; exit 2 ;;
esac
