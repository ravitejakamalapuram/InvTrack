// Edge and FAB-clearance guard on a 411dp phone. See layout_guard_harness.dart.
import 'layout_guard_harness.dart';
import 'layout_guard_states.dart';

void main() {
  defineEdgeGuardTests(width: 411);
  defineStateGuardTests(width: 411);
  defineInsetGuardTest(width: 411, inset: 48);
}
