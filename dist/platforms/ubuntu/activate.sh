#!/usr/bin/env bash

if [[ -n "$UNITY_SERIAL" && -n "$UNITY_EMAIL" && -n "$UNITY_PASSWORD" ]]; then
  #
  # SERIAL LICENSE MODE
  #
  # This will activate unity, using the activating process.
  #
  echo "Requesting activation"

  # Loop the unity-editor call until the license is activated with exponential backoff and a maximum of 5 retries
  retry_count=0

  # Initialize delay to 15 seconds
  delay=15

  # Loop until UNITY_EXIT_CODE is 0 or retry count reaches 5
  while [[ $retry_count -lt 5 ]]
  do
    # Activate license
    # Use an array to safely pass arguments with special characters (including quotes, *, #, }, >, etc.)
    # Build the array element by element to ensure proper handling of special characters
    # Note: Using "$VAR" in array assignment should handle special chars, but we'll be extra safe
    unity_args=(-logFile /dev/stdout -quit)
    unity_args+=(-serial "$UNITY_SERIAL")
    unity_args+=(-username "$UNITY_EMAIL")
    # For password, ensure it's passed as a single argument even with special characters
    unity_args+=(-password)
    unity_args+=("$UNITY_PASSWORD")
    unity_args+=(-projectPath /BlankProject)
    
    unity-editor "${unity_args[@]}"

    # Store the exit code from the verify command
    UNITY_EXIT_CODE=$?

    # Check if UNITY_EXIT_CODE is 0
    if [[ $UNITY_EXIT_CODE -eq 0 ]]
    then
      echo "Activation successful"
      break
    else
      # Increment retry count
      ((retry_count++))

      echo "::warning ::Activation failed, attempting retry #$retry_count"
      echo "Activation failed, retrying in $delay seconds..."
      sleep $delay

      # Double the delay for the next iteration
      delay=$((delay * 2))
    fi
  done

  if [[ $retry_count -eq 5 ]]
  then
    echo "Activation failed after 5 retries"
  fi

elif [[ -n "$UNITY_LICENSING_SERVER" ]]; then
  #
  # Custom Unity License Server
  #
  echo "Adding licensing server config"

  /opt/unity/Editor/Data/Resources/Licensing/Client/Unity.Licensing.Client --acquire-floating > license.txt #is this accessible in a env variable?
  UNITY_EXIT_CODE=$?
  PARSEDFILE=$(grep -oP '\".*?\"' < license.txt | tr -d '"')
  export FLOATING_LICENSE
  FLOATING_LICENSE=$(sed -n 2p <<< "$PARSEDFILE")
  FLOATING_LICENSE_TIMEOUT=$(sed -n 4p <<< "$PARSEDFILE")

  if [[ -z "$FLOATING_LICENSE" || -z "$FLOATING_LICENSE_TIMEOUT" ]]; then
    echo "::error ::Failed to acquire floating license from Unity Licensing Server."
    echo "Check the activation log below for more details."
    cat license.txt
  else
    echo "Acquired floating license: \"$FLOATING_LICENSE\" with timeout $FLOATING_LICENSE_TIMEOUT"
  fi

  # Store the exit code from the verify command
else
  #
  # NO LICENSE ACTIVATION STRATEGY MATCHED
  #
  # This will exit since no activation strategies could be matched.
  #
  echo "License activation strategy could not be determined."
  echo ""
  echo "Visit https://game.ci/docs/github/activation for more"
  echo "details on how to set up one of the possible activation strategies."

  echo "::error ::No valid license activation strategy could be determined. Make sure to provide UNITY_EMAIL, UNITY_PASSWORD, and either a UNITY_SERIAL \
or UNITY_LICENSE. Otherwise please use UNITY_LICENSING_SERVER."
  # Immediately exit as no UNITY_EXIT_CODE can be derived.
  exit 1;

fi

#
# Display information about the result
#
if [ $UNITY_EXIT_CODE -eq 0 ]; then
  # Activation was a success
  echo "Activation complete."
else
  # Activation failed so exit with the code from the license verification step
  echo "Unclassified error occured while trying to activate license."
  echo "Exit code was: $UNITY_EXIT_CODE"
  echo "::error ::There was an error while trying to activate the Unity license."
  exit $UNITY_EXIT_CODE
fi
