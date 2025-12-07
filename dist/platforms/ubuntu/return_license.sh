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
  # Use an array to safely pass arguments with special characters (including quotes, *, #, }, >, etc.)
  unity_args=(
    -logFile /dev/stdout
    -quit
    -returnlicense
    -username "$UNITY_EMAIL"
    -password "$UNITY_PASSWORD"
    -projectPath /BlankProject
  )
  
  unity-editor "${unity_args[@]}"
fi
