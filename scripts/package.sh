# Go to build dir
cd build

# Create package dir
mkdir -p package/addons/sourcemod/plugins
mkdir -p package/addons/sourcemod/configs
mkdir -p package/addons/sourcemod/gamedata
mkdir -p package/addons/sourcemod/translations

# Copy all required stuffs to package
cp -r addons/sourcemod/plugins/engiesvszombies.smx package/addons/sourcemod/plugins
cp -r ../addons/sourcemod/configs/evz package/addons/sourcemod/configs
cp -r ../addons/sourcemod/gamedata/evz.txt package/addons/sourcemod/gamedata
cp -r ../addons/sourcemod/translations/engiesvszombies.phrases.txt package/addons/sourcemod/translations
cp -r ../sound package