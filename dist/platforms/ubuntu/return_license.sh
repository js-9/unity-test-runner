#!/usr/bin/env bash

if [[ -n "$UNITY_LICENSING_SERVER" ]]; then
  #
  # Return any floating license used.
  #
  echo "Returning floating license: \"$FLOATING_LICENSE\""
  /opt/unity/Editor/Data/Resources/Licensing/Client/Unity.Licensing.Client --return-floating "$FLOATING_LICENSE"
elif [[ -n "$UNITY_SERIAL" ]]; then
  #
  # SERIAL LICENSE MODE
  #
  # This will return the license that is currently in use.
  #
  # Use printf %q to safely escape special characters (including quotes, *, #, }, >, etc.)
  UNITY_EMAIL_ESCAPED=$(printf '%q' "$UNITY_EMAIL")
  UNITY_PASSWORD_ESCAPED=$(printf '%q' "$UNITY_PASSWORD")
  
  eval "unity-editor \
    -logFile /dev/stdout \
    -quit \
    -returnlicense \
    -username $UNITY_EMAIL_ESCAPED \
    -password $UNITY_PASSWORD_ESCAPED \
    -projectPath /BlankProject"
fi
