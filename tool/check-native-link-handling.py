"""Check that packaged custom links have app_links as their sole handler."""
import argparse
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET


ANDROID = '{http://schemas.android.com/apk/res/android}'


def check_android(path):
    application = ET.parse(path).getroot().find('application')
    if application is None:
        raise ValueError(f'{path}: application missing')
    handlers = []
    for activity in list(application.findall('activity')) + list(application.findall('activity-alias')):
        if any(data.get(ANDROID + 'scheme') == 'vocabkr'
               for intent in activity.findall('intent-filter') for data in intent.findall('data')):
            handlers.append(activity)
    if not handlers:
        raise ValueError(f'{path}: vocabkr intent handler missing')
    for handler in handlers:
        flags = [entry.get(ANDROID + 'value') for entry in handler.findall('meta-data')
                 if entry.get(ANDROID + 'name') == 'flutter_deeplinking_enabled']
        if flags != ['false']:
            raise ValueError(f'{path}: {handler.get(ANDROID + "name")} must disable embedding deep links')


def check_ios(path):
    with path.open('rb') as stream:
        info = plistlib.load(stream)
    if info.get('FlutterDeepLinkingEnabled') is not False:
        raise ValueError(f'{path}: embedding deep links must be disabled')
    if not any('vocabkr' in entry.get('CFBundleURLSchemes', [])
               for entry in info.get('CFBundleURLTypes', [])):
        raise ValueError(f'{path}: vocabkr URL scheme missing')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--android-manifest', type=Path)
    parser.add_argument('--android-build-dir', type=Path)
    parser.add_argument('--ios-plist', type=Path)
    args = parser.parse_args()
    if not any((args.android_manifest, args.android_build_dir, args.ios_plist)):
        parser.error('provide an Android manifest/build directory or iOS plist')
    try:
        if args.android_manifest:
            check_android(args.android_manifest)
        if args.android_build_dir:
            candidates = [path for path in args.android_build_dir.rglob('AndroidManifest.xml')
                          if any(part in ('merged_manifest', 'merged_manifests', 'packaged_manifests')
                                 for part in path.parts)]
            for variant in ('debug', 'profile'):
                manifests = [path for path in candidates if variant in path.parts]
                if not manifests:
                    raise ValueError(f'No merged {variant} manifest under {args.android_build_dir}')
                for manifest in manifests:
                    check_android(manifest)
        if args.ios_plist:
            check_ios(args.ios_plist)
    except (OSError, ValueError, ET.ParseError, plistlib.InvalidFileException) as error:
        parser.error(str(error))
    print('Native custom links belong exclusively to app_links.')


if __name__ == '__main__':
    main()
