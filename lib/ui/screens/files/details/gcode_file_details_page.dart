import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/ui/screens/files/details/gcode_file_details_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/time_util.dart';

class GCodeFileDetailPage extends ConsumerWidget {
  const GCodeFileDetailPage({Key? key, required this.gcodeFile})
      : super(key: key);
  final GCodeFile gcodeFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [gcodeProvider.overrideWithValue(gcodeFile)
      ,gcodeFileDetailsControllerProvider],
      child: const _GCodeFileDetailPage(),
    );
  }
}

class _GCodeFileDetailPage extends ConsumerWidget {
  const _GCodeFileDetailPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var gcodeFile = ref.watch(gcodeProvider);

    var fileUrl = ref
        .watch(selectedMachineProvider.selectAs((data) => data?.httpUrl))
        .value;

    return Scaffold(
      // appBar: AppBar(
      //   title: Text(
      //     file.name,
      //     overflow: TextOverflow.fade,
      //   ),
      // ),
      body: CustomScrollView(
        slivers: [
          SliverLayoutBuilder(builder: (context, constraints) {
            return SliverAppBar(
              expandedHeight: 220,
              floating: true,
              actions: const [PreHeatBtn()],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Hero(
                  tag: 'gCodeImage-${gcodeFile.hashCode}',
                  child: (fileUrl != null && gcodeFile.bigImagePath != null)
                      ? CachedNetworkImage(
                          imageUrl:
                              '$fileUrl/server/files/${gcodeFile.parentPath}/${gcodeFile.bigImagePath}',
                          imageBuilder: (context, imageProvider) => Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Image(
                                image: imageProvider,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                              Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8.0)),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withOpacity(0.8),
                                  ),
                                  child: Text(
                                    gcodeFile.name,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 5,
                                    style: Theme.of(context)
                                        .textTheme
                                        .subtitle2
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer),
                                  ))
                            ],
                          ),
                          placeholder: (context, url) =>
                              const Icon(Icons.insert_drive_file),
                          errorWidget: (context, url, error) => Column(
                            children: [
                              const Expanded(
                                  child: Icon(Icons.file_present)),
                              Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8.0)),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withOpacity(0.8),
                                  ),
                                  child: Text(
                                    gcodeFile.name,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 5,
                                    style: Theme.of(context)
                                        .textTheme
                                        .subtitle2
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer),
                                  ))
                            ],
                          ),
                        )
                      : const Icon(Icons.insert_drive_file),
                ),
              ),
            );
          }),
          SliverToBoxAdapter(
            child: Column(children: [
              Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(
                          FlutterIcons.printer_3d_nozzle_outline_mco),
                      title: const Text('pages.setting.general.title').tr(),
                    ),
                    const Divider(),
                    PropertyTile(
                        title: 'pages.files.details.general_card.path'.tr(),
                        subtitle: gcodeFile.absolutPath),
                    PropertyTile(
                      title: 'pages.files.details.general_card.last_mod'.tr(),
                      subtitle: DateFormat.yMMMd()
                          .add_Hm()
                          .format(gcodeFile.modifiedDate),
                    ),
                    PropertyTile(
                      title:
                          'pages.files.details.general_card.last_printed'.tr(),
                      subtitle: (gcodeFile.printStartTime != null)
                          ? DateFormat.yMMMd()
                              .add_Hm()
                              .format(gcodeFile.lastPrintDate!)
                          : 'pages.files.details.general_card.no_data'.tr(),
                    ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(FlutterIcons.tags_ant),
                      title: const Text('pages.files.details.meta_card.title')
                          .tr(),
                    ),
                    const Divider(),
                    PropertyTile(
                      title: 'pages.files.details.meta_card.filament'.tr(),
                      subtitle:
                          '${tr('pages.files.details.meta_card.filament_type')}: ${gcodeFile.filamentType ?? tr('general.unknown')}\n'
                          '${tr('pages.files.details.meta_card.filament_name')}: ${gcodeFile.filamentName ?? tr('general.unknown')}',
                    ),
                    PropertyTile(
                      title:
                          'pages.files.details.meta_card.est_print_time'.tr(),
                      subtitle:
                          '${secondsToDurationText(gcodeFile.estimatedTime ?? 0)}, ${tr('pages.dashboard.general.print_card.eta')}: ${formatPotentialEta(gcodeFile)}',
                    ),
                    PropertyTile(
                      title: 'pages.files.details.meta_card.slicer'.tr(),
                      subtitle: formatSlicerAndVersion(gcodeFile),
                    ),
                    PropertyTile(
                      title:
                          'pages.files.details.meta_card.nozzle_diameter'.tr(),
                      subtitle: '${gcodeFile.nozzleDiameter} mm',
                    ),
                    PropertyTile(
                      title: 'pages.files.details.meta_card.layer_higher'.tr(),
                      subtitle:
                          '${tr('pages.files.details.meta_card.first_layer')}: ${gcodeFile.firstLayerHeight?.toStringAsFixed(2) ?? '?'} mm\n'
                          '${tr('pages.files.details.meta_card.others')}: ${gcodeFile.layerHeight?.toStringAsFixed(2) ?? '?'} mm',
                    ),
                    PropertyTile(
                      title: 'pages.files.details.meta_card.first_layer_temps'
                          .tr(),
                      subtitle:
                          'pages.files.details.meta_card.first_layer_temps_value'
                              .tr(args: [
                        gcodeFile.firstLayerTempExtruder?.toStringAsFixed(0) ??
                            'general.unknown'.tr(),
                        gcodeFile.firstLayerTempBed?.toStringAsFixed(0) ??
                            'general.unknown'.tr()
                      ]),
                    ),
                  ],
                ),
              ),
              // Card(
              //   child: Column(
              //     mainAxisSize: MainAxisSize.min,
              //     children: <Widget>[
              //       ListTile(
              //         leading: Icon(FlutterIcons.chart_bar_mco),
              //         title: Text('pages.files.details.stat_card.title').tr(),
              //       ),
              //       Divider(),
              //       Placeholder(
              //
              //       )
              //     ],
              //   ),
              // ),
              const SizedBox(
                height: 100,
              )
            ]),
          )
        ],
      ),

      floatingActionButton: const Fab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String formatSlicerAndVersion(GCodeFile file) {
    String ukwn = tr('general.unknown');
    if (file.slicerVersion == null) return file.slicer ?? ukwn;

    return '${file.slicer ?? ukwn} (v${file.slicerVersion})';
  }

  String formatPotentialEta(GCodeFile file) {
    if (file.estimatedTime == null) return tr('general.unknown');
    var eta = DateTime.now()
        .add(Duration(seconds: file.estimatedTime!.toInt()))
        .toLocal();
    return DateFormat.MMMEd().add_Hm().format(eta);
  }
}

class Fab extends ConsumerWidget {
  const Fab({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var canStartPrint = ref.watch(canStartPrintProvider);

    return FloatingActionButton.extended(
      backgroundColor: (canStartPrint) ? null : Theme.of(context).disabledColor,
      onPressed: (canStartPrint)
          ? ref
              .watch(gcodeFileDetailsControllerProvider.notifier)
              .onStartPrintTap
          : null,
      icon: const Icon(FlutterIcons.printer_3d_nozzle_mco),
      label: const Text('pages.files.details.print').tr(),
    );
  }
}

class PreHeatBtn extends ConsumerWidget {
  const PreHeatBtn({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: ref.watch(gcodeProvider).firstLayerTempBed != null &&
              ref.watch(canStartPrintProvider)
          ? ref
              .watch(gcodeFileDetailsControllerProvider.notifier)
              .onPreHeatPrinterTap
          : null,
      icon: const Icon(
        FlutterIcons.fire_alt_faw5s,
      ),
      tooltip: 'pages.files.details.preheat'.tr(),
    );
  }
}

class PropertyTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const PropertyTile({Key? key, required this.title, required this.subtitle})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    var subtitleTheme = textTheme.bodyText2
        ?.copyWith(fontSize: 13, color: textTheme.caption?.color);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.left,
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            subtitle,
            style: subtitleTheme,
            textAlign: TextAlign.left,
          )
        ],
      ),
    );
  }
}
