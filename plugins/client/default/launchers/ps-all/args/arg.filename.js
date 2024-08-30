/**
 * filename argument in this plugin will LanmanWorkstation_${timestamp}.${fileExtension}
 * every time launcher is evaluated, the filename will be different.
 * This is useful for rapid Launcher generation.
 *
 *
 * The last line of this file is the return value for the plugin.
 *
 * previously evaluated variables can be accessed by: argumentsPluginInterface["args.name"]
 */

const timestamp = new Date().getTime();
const payloadType = payload.configuration.type;
const fileExtension = payloadsStore().extensionMap.get(payloadType);

`LanmanWorkstation_${timestamp}.${fileExtension}`;
