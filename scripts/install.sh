# Create build folder
mkdir build
cd build

# Install SourceMod
wget --input-file=http://sourcemod.net/smdrop/$SM_VERSION/sourcemod-latest-linux
tar -xzf $(cat sourcemod-latest-linux)

# Copy sp and compiler to build dir
cp -r ../addons/sourcemod/scripting addons/sourcemod
cd addons/sourcemod/scripting

# Install Dependencies
wget "https://raw.githubusercontent.com/FlaminSarge/tf2attributes/master/scripting/include/tf2attributes.inc" -O include/tf2attributes.inc
wget "https://raw.githubusercontent.com/nosoop/SM-TFEconData/master/scripting/include/tf_econ_data.inc" -O include/tf_econ_data.inc
wget "https://raw.githubusercontent.com/asherkin/TF2Items/master/pawn/tf2items.inc" -O include/tf2items.inc
wget "https://www.doctormckay.com/download/scripting/include/morecolors.inc" -O include/morecolors.inc