import 'dart:io';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/fans/generic_fan.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/dto/machine/output_pin.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/moonraker_db/gcode_macro.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/power_api_panel.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/control_tab_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stringr/stringr.dart';

class ControlTab extends ConsumerWidget {
  const ControlTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((data) => true))
        .when(
            data: (data) {
              return PullToRefreshPrinter(
                child: ListView(
                  key: const PageStorageKey<String>('cTab'),
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    if (ref
                        .watch(machinePrinterKlippySettingsProvider.selectAs(
                            (value) => value.settings.macroGroups.isNotEmpty))
                        .valueOrFullNull!)
                      const GcodeMacroCard(),
                    if (ref
                        .watch(machinePrinterKlippySettingsProvider.selectAs(
                            (value) =>
                                value.printerData.print.state !=
                                PrintState.printing))
                        .valueOrFullNull!)
                      const ExtruderControlCard(),
                    const FansCard(),
                    if (ref
                        .watch(machinePrinterKlippySettingsProvider.selectAs(
                            (value) => value.printerData.outputPins.isNotEmpty))
                        .valueOrFullNull!)
                      const PinsCard(),
                    if (ref
                        .watch(machinePrinterKlippySettingsProvider.selectAs(
                            (value) =>
                                value.klippyData.components.contains('power')))
                        .valueOrFullNull!)
                      const PowerApiCard(),
                    const MultipliersCard(),
                    const LimitsCard(),
                  ],
                ),
              );
            },
            error: (e, s) {
              logger.e('Cought error in Controller tab', e, s);
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(FlutterIcons.sad_cry_faw5s, size: 99),
                    const SizedBox(
                      height: 22,
                    ),
                    const Text(
                      'Error while trying to fetch printer...\nPlease provide the error to the project owner\nvia GitHub!',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                        // onPressed: model.showPrinterFetchingErrorDialog,
                        onPressed: () => ref.read(dialogServiceProvider).show(
                            DialogRequest(
                                type: DialogType.stacktrace,
                                title: e.runtimeType.toString(),
                                body: 'Exception:\n $e\n\n$s')),
                        child: const Text('Show Error'))
                  ],
                ),
              );
            },
            loading: () => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitRipple(
                        color: Theme.of(context).colorScheme.secondary,
                        size: 100,
                      ),
                      const SizedBox(
                        height: 30,
                      ),
                      FadingText('Fetching printer data'),
                      // Text('Fetching printer ...')
                    ],
                  ),
                ));
  }
}

class FansCard extends ConsumerWidget {
  const FansCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fanLen = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value
            .printerData.fans
            .where((element) => !element.name.startsWith('_'))
            .length))
        .valueOrFullNull!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                FlutterIcons.fan_mco,
              ),
              title: const Text('pages.dashboard.control.fan_card.title')
                  .plural(fanLen),
            ),
            AdaptiveHorizontalScroll(pageStorageKey: 'fans', children: [
              const _PrintFan(),
              ...List.generate(fanLen, (index) {
                var fanProvider = machinePrinterKlippySettingsProvider.selectAs(
                    (value) => value.printerData.fans
                        .where((element) => !element.name.startsWith('_'))
                        .elementAt(index));

                return _Fan(
                  fanProvider: fanProvider,
                );
              }),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PrintFan extends ConsumerWidget {
  const _PrintFan({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fan = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.printerData.printFan))
        .valueOrFullNull!;
    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrFullNull!;

    return _FanCard(
      name: 'pages.dashboard.control.fan_card.part_fan'.tr(),
      speed: fan.speed,
      onTap: klippyCanReceiveCommands
          ? () =>
              ref.read(controlTabControllerProvider.notifier).onEditPartFan(fan)
          : null,
    );
  }
}

class _Fan extends ConsumerWidget {
  const _Fan({Key? key, required this.fanProvider}) : super(key: key);

  final ProviderListenable<AsyncValue<NamedFan>> fanProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fan = ref.watch(fanProvider).valueOrFullNull!;
    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrFullNull!;
    return _FanCard(
      name: beautifyName(fan.name),
      speed: fan.speed,
      onTap: klippyCanReceiveCommands && (fan is GenericFan)
          ? () => ref
              .read(controlTabControllerProvider.notifier)
              .onEditGenericFan(fan)
          : null,
    );
  }
}

class _FanCard extends StatelessWidget {
  static const double icoSize = 30;

  final String name;
  final double speed;
  final VoidCallback? onTap;

  const _FanCard({
    Key? key,
    required this.name,
    required this.speed,
    this.onTap,
  }) : super(key: key);

  String get fanSpeed {
    double fanPerc = speed * 100;
    if (speed > 0) return '${fanPerc.toStringAsFixed(0)} %';
    return 'general.off'.tr();
  }

  @override
  Widget build(BuildContext context) {
    return CardWithButton(
        buttonChild: onTap == null
            ? const Text('pages.dashboard.control.fan_card.static_fan_btn').tr()
            : const Text('general.set').tr(),
        onTap: onTap,
        builder: (context) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.caption),
                  Text(fanSpeed, style: Theme.of(context).textTheme.headline6),
                ],
              ),
              speed > 0
                  ? const SpinningFan(size: icoSize)
                  : const Icon(
                      FlutterIcons.fan_off_mco,
                      size: icoSize,
                    ),
            ],
          );
        });
  }
}

class SpinningFan extends HookWidget {
  const SpinningFan({Key? key, required this.size}) : super(key: key);

  final double? size;

  @override
  Widget build(BuildContext context) {
    AnimationController animationController =
        useAnimationController(duration: const Duration(seconds: 3))..repeat();
    return RotationTransition(
      turns: animationController,
      child: Icon(FlutterIcons.fan_mco, size: size),
    );
  }
}

class ExtruderControlCard extends HookConsumerWidget {
  const ExtruderControlCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var activeExtruderIdx =
        ref.watch(machinePrinterKlippySettingsProvider.selectAs((value) {
      String activeIdx = value.printerData.toolhead.activeExtruder.substring(8);
      return int.tryParse(activeIdx) ?? 0;
    })).valueOrFullNull!;

    var minExtrudeTemp = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) =>
            value.printerData.configFile
                .extruderForIndex(activeExtruderIdx)
                ?.minExtrudeTemp ??
            170))
        .valueOrFullNull!;

    var canExtrude = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) =>
            value.printerData.extruders[activeExtruderIdx].temperature >=
            minExtrudeTemp))
        .valueOrFullNull!;

    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrFullNull!;

    var extruderSteps = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.settings.extrudeSteps))
        .valueOrFullNull!;

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
            title: Row(
              children: [
                const Text('pages.dashboard.control.extrude_card.title').tr(),
                AnimatedOpacity(
                  opacity: canExtrude ? 0 : 1,
                  duration: kThemeAnimationDuration,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Tooltip(
                      message: tr(
                          'pages.dashboard.control.extrude_card.cold_extrude_error',
                          args: [minExtrudeTemp.toStringAsFixed(0)]),
                      child: Icon(
                        Icons.severe_cold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                )
              ],
            ),
            trailing: (ref
                    .watch(machinePrinterKlippySettingsProvider.selectAs(
                        (value) => value.printerData.extruderCount > 1))
                    .valueOrFullNull!)
                ? DropdownButton(
                    value: activeExtruderIdx,
                    onChanged: klippyCanReceiveCommands
                        ? ref
                            .watch(controlTabControllerProvider.notifier)
                            .onExtruderSelected
                        : null,
                    items: List.generate(
                        ref
                            .watch(
                                machinePrinterKlippySettingsProvider.selectAs(
                                    (value) => value.printerData.extruderCount))
                            .valueOrFullNull!, (index) {
                      String name =
                          tr('pages.dashboard.control.extrude_card.title');
                      if (index > 0) name += ' $index';
                      return DropdownMenuItem(
                        value: index,
                        child: Text(name),
                      );
                    }))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton.icon(
                        onPressed: klippyCanReceiveCommands && canExtrude
                            ? ref
                                .watch(extruderControlCardControllerProvider
                                    .notifier)
                                .onRetractBtn
                            : null,
                        icon: const Icon(FlutterIcons.minus_ant),
                        label: const Text(
                                'pages.dashboard.control.extrude_card.retract')
                            .tr(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton.icon(
                        onPressed: klippyCanReceiveCommands && canExtrude
                            ? ref
                                .watch(extruderControlCardControllerProvider
                                    .notifier)
                                .onExtrudeBtn
                            : null,
                        icon: const Icon(FlutterIcons.plus_ant),
                        label: const Text(
                                'pages.dashboard.control.extrude_card.extrude')
                            .tr(),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          '${tr('pages.dashboard.control.extrude_card.extrude_len')} [mm]'),
                    ),
                    RangeSelector(
                        selectedIndex:
                            ref.watch(extruderControlCardControllerProvider),
                        onSelected: ref
                            .watch(
                                extruderControlCardControllerProvider.notifier)
                            .stepChanged,
                        values:
                            extruderSteps.map((e) => e.toString()).toList()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GcodeMacroCard extends HookConsumerWidget {
  const GcodeMacroCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrFullNull!;

    var macroGroups = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.settings.macroGroups))
        .valueOrFullNull!;

    var isPrinting = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs(
            (value) => value.printerData.print.state == PrintState.printing))
        .valueOrFullNull!;

    int idx = min(
        macroGroups.length - 1,
        max(
            0,
            ref
                .watch(settingServiceProvider)
                .readInt(selectedGCodeGrpIndex, 0)));

    var selected = useState(idx);
    var themeData = Theme.of(context);

    var macrosOfGrp = macroGroups[selected.value].macros;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(FlutterIcons.code_braces_mco),
            title: const Text('pages.dashboard.control.macro_card.title').tr(),
            trailing: (macroGroups.length > 1)
                ? DropdownButton<int>(
                    value: selected.value,
                    onChanged: klippyCanReceiveCommands
                        ? (e) {
                            ref
                                .read(settingServiceProvider)
                                .writeInt(selectedGCodeGrpIndex, e!);
                            selected.value = e;
                          }
                        : null,
                    items: macroGroups.mapIndex((e, i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text(e.name),
                      );
                    }).toList())
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: ChipTheme(
              data: ChipThemeData(
                  labelStyle:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  deleteIconColor: Theme.of(context).colorScheme.onPrimary),
              child: Wrap(
                spacing: 5.0,
                children: List<Widget>.generate(
                  macrosOfGrp.length,
                  (int index) {
                    GCodeMacro macro = macrosOfGrp[index];
                    bool disabled = (!klippyCanReceiveCommands ||
                        (isPrinting && !macro.showWhilePrinting));
                    return Visibility(
                      visible: ref
                              .watch(
                                  machinePrinterKlippySettingsProvider.selectAs(
                                      (value) => value.printerData.gcodeMacros
                                          .contains(macro.name)))
                              .valueOrFullNull! &&
                          macro.visible,
                      child: ActionChip(
                        label: Text(macro.beautifiedName),
                        backgroundColor: disabled
                            ? themeData.disabledColor
                            : themeData.colorScheme.primary,
                        onPressed: () => disabled
                            ? null
                            : ref
                                .watch(controlTabControllerProvider.notifier)
                                .onMacroPressed(macro.name),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PinsCard extends ConsumerWidget {
  const PinsCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pinLen = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value
            .printerData.outputPins
            .where((element) => !element.name.startsWith('_'))
            .length))
        .valueOrFullNull!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                FlutterIcons.led_outline_mco,
              ),
              title: Text(
                  plural('pages.dashboard.control.pin_card.title', pinLen)),
            ),
            AdaptiveHorizontalScroll(
              pageStorageKey: 'pins',
              children: List.generate(pinLen, (index) {
                var pinProvider = machinePrinterKlippySettingsProvider.selectAs(
                    (value) => value.printerData.outputPins
                        .where((element) => !element.name.startsWith('_'))
                        .elementAt(index));

                return _PinTile(pinProvider: pinProvider);
              }),
            )
          ],
        ),
      ),
    );
  }
}

class _PinTile extends ConsumerWidget {
  const _PinTile({Key? key, required this.pinProvider}) : super(key: key);
  final ProviderListenable<AsyncValue<OutputPin>> pinProvider;

  String pinValue(double v) {
    if (v > 0) return NumberFormat('0.##').format(v);

    return 'general.off'.tr();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pin = ref.watch(pinProvider).valueOrFullNull!;
    var pinConfig = ref.watch(machinePrinterKlippySettingsProvider.select(
        (value) =>
            value.valueOrFullNull?.printerData.configFile.outputs[pin.name]));
    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrFullNull!;

    return CardWithButton(
        buttonChild: const Text('general.set').tr(),
        onTap: klippyCanReceiveCommands
            ? () => ref
                .read(controlTabControllerProvider.notifier)
                .onEditPin(pin, pinConfig)
            : null,
        builder: (context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(beautifyName(pin.name),
                  style: Theme.of(context).textTheme.caption),
              Text(pinValue(pin.value * (pinConfig?.scale ?? 1)),
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          );
        });
  }
}

class MultipliersCard extends HookConsumerWidget {
  const MultipliersCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var inputLocked = useState(true);

    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrFullNull!;

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(FlutterIcons.speedometer_slow_mco),
            title:
                const Text('pages.dashboard.control.multipl_card.title').tr(),
            trailing: IconButton(
                onPressed: klippyCanReceiveCommands
                    ? () => inputLocked.value = !inputLocked.value
                    : null,
                icon: AnimatedSwitcher(
                  duration: kThemeAnimationDuration,
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: inputLocked.value
                      ? const Icon(FlutterIcons.lock_faw, key: ValueKey('lock'))
                      : const Icon(FlutterIcons.unlock_faw,
                          key: ValueKey('unlock')),
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              children: [
                _SliderOrTextInput(
                  initialValue: ref.watch(
                      machinePrinterKlippySettingsProvider.select((value) =>
                          value.value!.printerData.gCodeMove.speedFactor)),
                  prefixText: 'pages.dashboard.general.print_card.speed'.tr(),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref
                          .watch(controlTabControllerProvider.notifier)
                          .onEditedSpeedMultiplier
                      : null,
                ),
                _SliderOrTextInput(
                    initialValue: ref.watch(
                        machinePrinterKlippySettingsProvider.select((value) =>
                            value.value!.printerData.gCodeMove.extrudeFactor)),
                    prefixText:
                        'pages.dashboard.control.multipl_card.flow'.tr(),
                    onChange: klippyCanReceiveCommands && !inputLocked.value
                        ? ref
                            .watch(controlTabControllerProvider.notifier)
                            .onEditedFlowMultiplier
                        : null),
                _SliderOrTextInput(
                  initialValue: ref.watch(
                      machinePrinterKlippySettingsProvider.select((value) =>
                          value.value!.printerData.extruder.pressureAdvance)),
                  prefixText:
                      'pages.dashboard.control.multipl_card.press_adv'.tr(),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref
                          .watch(controlTabControllerProvider.notifier)
                          .onEditedPressureAdvanced
                      : null,
                  numberFormat: NumberFormat('0.##### mm/s'),
                  unit: 'mm/s',
                ),
                _SliderOrTextInput(
                  initialValue: ref.watch(
                      machinePrinterKlippySettingsProvider.select((value) =>
                          value.value!.printerData.extruder.smoothTime)),
                  prefixText:
                      'pages.dashboard.control.multipl_card.smooth_time'.tr(),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref
                          .watch(controlTabControllerProvider.notifier)
                          .onEditedSmoothTime
                      : null,
                  numberFormat: NumberFormat('0.### s'),
                  maxValue: 0.2,
                  unit: 's',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LimitsCard extends HookConsumerWidget {
  const LimitsCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var inputLocked = useState(true);

    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrFullNull!;

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('pages.dashboard.control.limit_card.title').tr(),
            trailing: IconButton(
                onPressed: (klippyCanReceiveCommands)
                    ? () => inputLocked.value = !inputLocked.value
                    : null,
                icon: AnimatedSwitcher(
                  duration: kThemeAnimationDuration,
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: inputLocked.value
                      ? const Icon(FlutterIcons.lock_faw, key: ValueKey('lock'))
                      : const Icon(FlutterIcons.unlock_faw,
                          key: ValueKey('unlock')),
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              children: [
                _SliderOrTextInput(
                  initialValue: ref.watch(
                      machinePrinterKlippySettingsProvider.select((value) =>
                          value.value!.printerData.toolhead.maxVelocity)),
                  prefixText: tr('pages.dashboard.control.limit_card.velocity'),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref
                          .watch(controlTabControllerProvider.notifier)
                          .onEditedMaxVelocity
                      : null,
                  numberFormat: NumberFormat('0 mm/s'),
                  unit: 'mm/s',
                  maxValue: 500,
                ),
                _SliderOrTextInput(
                  initialValue: ref.watch(
                      machinePrinterKlippySettingsProvider.select((value) =>
                          value.value!.printerData.toolhead.maxAccel)),
                  prefixText: tr('pages.dashboard.control.limit_card.accel'),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref
                          .watch(controlTabControllerProvider.notifier)
                          .onEditedMaxAccel
                      : null,
                  numberFormat: NumberFormat('0 mm/s²'),
                  unit: 'mm/s²',
                  maxValue: 5000,
                ),
                _SliderOrTextInput(
                  initialValue: ref.watch(machinePrinterKlippySettingsProvider
                      .select((value) => value
                          .value!.printerData.toolhead.squareCornerVelocity)),
                  prefixText:
                      tr('pages.dashboard.control.limit_card.sq_corn_vel'),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref
                          .watch(controlTabControllerProvider.notifier)
                          .onEditedMaxSquareCornerVelocity
                      : null,
                  numberFormat: NumberFormat('0.# mm/s'),
                  unit: 'mm/s',
                  maxValue: 8,
                ),
                _SliderOrTextInput(
                  initialValue: ref.watch(
                      machinePrinterKlippySettingsProvider.select((value) =>
                          value.value!.printerData.toolhead.maxAccelToDecel)),
                  prefixText:
                      tr('pages.dashboard.control.limit_card.accel_to_decel'),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref
                          .watch(controlTabControllerProvider.notifier)
                          .onEditedMaxAccelToDecel
                      : null,
                  numberFormat: NumberFormat('0 mm/s²'),
                  unit: 'mm/s²',
                  maxValue: 3500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderOrTextInput extends HookWidget {
  final ValueChanged<double>? onChange;
  final String prefixText;
  final double initialValue;
  final NumberFormat? numberFormat;
  final double maxValue;
  final double minValue;
  final String? unit;

  const _SliderOrTextInput(
      {Key? key,
      required this.initialValue,
      required this.prefixText,
      required this.onChange,
      this.numberFormat,
      this.maxValue = 2,
      this.minValue = 0,
      this.unit})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var initial = useState(initialValue);
    var sliderPos = useState(initial.value);
    var fadeState = useState(CrossFadeState.showFirst);
    var textEditingController = useTextEditingController(text: '0');
    var focusText = useFocusNode();
    var focusRequested = useState(false);
    var inputValid = useState(true);

    NumberFormat numFormat = numberFormat ?? NumberFormat('###%');

    if (initial.value != initialValue) {
      initial.value = initialValue;
      sliderPos.value = initialValue;
      textEditingController.text =
          numFormat.format(initialValue).replaceAll(RegExp(r'[^0-9.,]'), '');
    }

    if (fadeState.value == CrossFadeState.showSecond &&
        !focusRequested.value &&
        !focusText.hasFocus &&
        focusText.canRequestFocus) {
      focusRequested.value = true;
      focusText.requestFocus();
    }

    Widget suffixText = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(unit ?? '%'),
    );

    return Row(
      children: [
        Flexible(
          child: AnimatedCrossFade(
            firstChild: InputDecorator(
                decoration: InputDecoration(
                  label:
                      Text('$prefixText: ${numFormat.format(sliderPos.value)}'),
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
                child: Slider(
                  value: min(maxValue, sliderPos.value),
                  onChanged: onChange != null
                      ? (v) {
                          sliderPos.value = v;
                        }
                      : null,
                  onChangeEnd: onChange,
                  max: maxValue,
                  min: minValue,
                )),
            secondChild: TextField(
              enabled: onChange != null,
              onSubmitted: (String value) {
                if (!inputValid.value) return;
                double perc =
                    numFormat.parse(textEditingController.text).toDouble();
                onChange!(perc);
              },
              focusNode: focusText,
              controller: textEditingController,
              onChanged: (s) {
                if (s.isEmpty || !RegExp(r'^\d+([.,])?\d*?$').hasMatch(s)) {
                  inputValid.value = false;
                  return;
                }

                if (!inputValid.value) inputValid.value = true;
              },
              textAlign: TextAlign.end,
              keyboardType:
                  TextInputType.numberWithOptions(signed: Platform.isIOS),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
              ],
              decoration: InputDecoration(
                  prefixText: '$prefixText:',
                  border: InputBorder.none,
                  suffix: suffixText,
                  errorText: !inputValid.value
                      ? FormBuilderLocalizations.current.numericErrorText
                      : null),
            ),
            duration: kThemeAnimationDuration,
            crossFadeState: fadeState.value,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: !inputValid.value || onChange == null
              ? null
              : () {
                  if (fadeState.value == CrossFadeState.showFirst) {
                    textEditingController.text = numFormat
                        .format(sliderPos.value)
                        .replaceAll(RegExp(r'[^0-9.,]'), '');
                    fadeState.value = CrossFadeState.showSecond;
                    focusRequested.value = false;
                  } else {
                    sliderPos.value =
                        numFormat.parse(textEditingController.text).toDouble();
                    fadeState.value = CrossFadeState.showFirst;
                    focusText.unfocus();
                  }
                },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 33, minHeight: 33),
        )
      ],
    );
  }
}
