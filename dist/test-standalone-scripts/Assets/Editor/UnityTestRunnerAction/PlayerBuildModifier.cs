using System;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEditor.TestTools;
using UnityEngine;
using UnityEngine.TestTools;
using UnityTestRunnerAction;

[assembly: TestPlayerBuildModifier(typeof(HeadlessPlayModeSetup))]
[assembly: PostBuildCleanup(typeof(HeadlessPlayModeSetup))]

namespace UnityTestRunnerAction
{
    public class HeadlessPlayModeSetup : ITestPlayerBuildModifier, IPostBuildCleanup
    {
        private static bool s_RunningPlayerTests;
        public BuildPlayerOptions ModifyOptions(BuildPlayerOptions playerOptions)
        {
            // Do not launch the player after the build completes. Disable the PlayerConnection.
            playerOptions.options &= ~(BuildOptions.AutoRunPlayer | BuildOptions.ConnectToHost | BuildOptions.WaitForPlayerConnection);

            // Not supporting Mac currently.
            playerOptions.target = SystemInfo.operatingSystemFamily == OperatingSystemFamily.Windows ? BuildTarget.StandaloneWindows64 : BuildTarget.StandaloneLinux64;

            string[] commandLineArgs = Environment.GetCommandLineArgs();
            playerOptions.locationPathName = commandLineArgs[Array.IndexOf(commandLineArgs, "-builtTestRunnerPath") + 1]; ;

            // Enable parallel linking for IL2CPP builds
            SetParallelLinking();

            // Instruct the cleanup to exit the Editor if the run came from the command line. 
            // The variable is static because the cleanup is being invoked in a new instance of the class.
            s_RunningPlayerTests = true;
            return playerOptions;
        }

        public void Cleanup()
        {
            if (s_RunningPlayerTests && IsRunningTestsFromCommandLine())
            {
                // Exit the Editor on the next update, allowing for other PostBuildCleanup steps to run.
                EditorApplication.update += () => { EditorApplication.Exit(0); };
            }
        }

        private static bool IsRunningTestsFromCommandLine()
        {
            var commandLineArgs = Environment.GetCommandLineArgs();
            return commandLineArgs.Any(value => value == "-runTests");
        }

        private static void SetParallelLinking()
        {
            // Get current additionalIl2CppArgs using reflection for Unity version compatibility
            string additionalArgs = GetAdditionalIl2CppArgs();

            // Determine number of parallel jobs (use CPU count, or default to 2)
            int numJobs = Environment.ProcessorCount;
            if (numJobs <= 0) numJobs = 2;

            // Use host platform (where Unity is running) instead of target platform to support cross-compilation
            // Platform-specific parallel linking flags based on the host platform
            RuntimePlatform hostPlatform = Application.platform;
            switch (hostPlatform)
            {
                case RuntimePlatform.WindowsEditor:
                case RuntimePlatform.WindowsPlayer:
                    string cgthreadsFlag = $"--linker-flags=/CGTHREADS:{numJobs}";
                    if (!additionalArgs.Contains("/CGTHREADS:"))
                    {
                        additionalArgs = string.IsNullOrEmpty(additionalArgs)
                            ? cgthreadsFlag
                            : $"{additionalArgs} {cgthreadsFlag}";
                    }
                    break;

                case RuntimePlatform.OSXEditor:
                case RuntimePlatform.OSXPlayer:
                case RuntimePlatform.LinuxEditor:
                case RuntimePlatform.LinuxPlayer:
                    if (!additionalArgs.Contains("--threads"))
                    {
                        additionalArgs = string.IsNullOrEmpty(additionalArgs)
                            ? $"-Wl,--threads={numJobs}"
                            : $"{additionalArgs} -Wl,--threads={numJobs}";
                    }
                    break;
            }

            SetAdditionalIl2CppArgs(additionalArgs);
            Debug.Log($"IL2CPP parallel linking enabled with {numJobs} jobs on host platform {hostPlatform}. Additional args: {additionalArgs}");
        }

        private static string GetAdditionalIl2CppArgs()
        {
            // Try to get additionalIl2CppArgs using reflection for Unity version compatibility
            var property = typeof(PlayerSettings).GetProperty("additionalIl2CppArgs", BindingFlags.Public | BindingFlags.Static);
            if (property != null)
            {
                return (string)property.GetValue(null) ?? string.Empty;
            }

            // Fallback: try SetAdditionalIl2CppArgs/GetAdditionalIl2CppArgs methods if available
            var getMethod = typeof(PlayerSettings).GetMethod("GetAdditionalIl2CppArgs", BindingFlags.Public | BindingFlags.Static);
            if (getMethod != null)
            {
                return (string)getMethod.Invoke(null, null) ?? string.Empty;
            }

            // If neither is available, return empty string
            return string.Empty;
        }

        private static void SetAdditionalIl2CppArgs(string args)
        {
            // Try to set additionalIl2CppArgs using reflection for Unity version compatibility
            var property = typeof(PlayerSettings).GetProperty("additionalIl2CppArgs", BindingFlags.Public | BindingFlags.Static);
            if (property != null)
            {
                property.SetValue(null, args);
                return;
            }

            // Fallback: try SetAdditionalIl2CppArgs method if available
            var setMethod = typeof(PlayerSettings).GetMethod("SetAdditionalIl2CppArgs", BindingFlags.Public | BindingFlags.Static);
            if (setMethod != null)
            {
                setMethod.Invoke(null, new object[] { args });
                return;
            }

            Debug.LogWarning("Could not set additionalIl2CppArgs - API not available in this Unity version");
        }
    }
}
