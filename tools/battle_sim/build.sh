#!/bin/bash
# Rebuilds the standalone simulator: tools/battle_sim/*.js + sim_data.json -> battle_simulator.html
# (run tools/export_battle_sim_data.gd first whenever the game's data changes).
cd "$(dirname "$0")" || exit 1
{ printf 'const SIM_DATA = '; cat sim_data.json; printf ';\n'; cat core.js player.js battle_a.js battle_b.js battle_c.js runner.js; } > engine_bundle.js
{ cat engine_bundle.js; echo; cat ui.js; } > app_bundle.js
build_html() { # template out bundle
  perl -e 'local $/; open(T,"<$ARGV[0]"); $t=<T>; close T; open(C,"<style.css"); $c=<C>; close C; open(J,"<$ARGV[2]"); $j=<J>; close J;
           $t =~ s/\/\*__CSS__\*\//$c/; $t =~ s/\/\*__JS__\*\//$j/; open(O,">$ARGV[1]"); print O $t; close O;' "$1" "$2" "$3"
}
build_html template.html ../../battle_simulator.html app_bundle.js
{ cat engine_bundle.js; [ -f parity_data.js ] && cat parity_data.js; } > selftest_bundle.js
build_html test_template.html selftest.html selftest_bundle.js
echo "built ../../battle_simulator.html ($(wc -c < ../../battle_simulator.html) bytes)"
rm -f engine_bundle.js app_bundle.js selftest_bundle.js
