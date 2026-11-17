#!/bin/sh
# Render the OSB icons from the SVG sources in this folder into the fork's
# asset catalogs and the web remote control's favicon. Needs resvg and Pillow.
set -eu
cd "$(dirname "$0")"
root=../..
app="$root/Moblin/OsbBrand.xcassets"
watch="$root/Moblin Watch/OsbBrand.xcassets"
widget="$root/Moblin Widget/OsbBrand.xcassets"
activity="$root/Moblin Live Activity/OsbBrand.xcassets"

render() {
    resvg --width "$3" --height "$3" "$1" "$2"
}

for appearance in light dark tinted; do
    render app-icon-$appearance.svg "$app/AppIcon.appiconset/app-icon-$appearance.png" 1024
done
render app-icon-light.svg "$watch/AppIcon.appiconset/app-icon.png" 1024
for name in AppIconNoBackground AlertFace; do
    render mark.svg "$app/$name.imageset/mark.png" 512
done
for catalog in "$widget" "$activity"; do
    render widget.svg "$catalog/AppIcon.imageset/widget.png" 512
done
render widget-accented.svg "$widget/AppIconAccented.imageset/widget-accented.png" 512

render favicon.svg favicon-64.png 64
python3 -c '
import sys
from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2], sizes=[(16, 16), (32, 32), (48, 48)])
' favicon-64.png "$root/Fork/Resources/favicon.ico"
rm favicon-64.png
