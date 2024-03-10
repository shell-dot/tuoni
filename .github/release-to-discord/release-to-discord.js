// code from https://github.com/sillyangel/releases-to-discord/blob/main/index.js, thanks to the author
// made some changes to the original code

import core from '@actions/core';
import github from '@actions/github';
import fetch from 'node-fetch';

/**
 * Stylizes a markdown body into an appropriate embed message style.
 *  H3s converted to bold and underlined.
 *  H2s converted to bold.
 *  Redundant whitespace and newlines removed.
 * @param description
 * @returns {*}
 */
const formatDescription = (description) => {
    return description
        .replace(/### (.*?)\n/g,function (substring) {
            const newString = substring.slice(4).replace(/(\r\n|\n|\r)/gm, "")
            return `**__${newString}__**`
        })
        .replace(/## (.*?)\n/g,function (substring) {
            const newString = substring.slice(3).replace(/(\r\n|\n|\r)/gm, "")
            return `**${newString}**`
        })
        .replace(/\n\s*\n/g, '\n')
}

/**
 * Get the context of the action, returns a GitHub Release payload.
 * @returns {Promise<{html_url, body: (*|string), version: string}>}
 */
async function getContext () {
    const payload = github.context.payload

    return {
        body: payload.release.body.length < 1500
            ? payload.release.body
            : payload.release.body.substring(0, 1500) + ` ([...](${payload.release.html_url}))`,
        version: payload.release.tag_name,
        html_url: payload.release.html_url
    }
}

/**
 * Handles the action.
 * Get inputs, creates a stylized response webhook, and sends it to the channel.
 * @returns {Promise<void>}
 */
async function run () {
    const webhookUrl = process.env.DISCORD_RELEASES_WEBHOOK_URL;
    const color = "2105893"
    const username = "release-bot"
    // const avatarUrl =

    if (!webhookUrl) return core.setFailed('webhook_url not set. Please set it.')

    const {body, html_url, version} = await getContext()

    const description = formatDescription(body)

    const embedMsg = {
        title: `Release ${version}`,
        url: html_url,
        color: color,
        description: description
    }

    const requestBody = {
        username: username,
        // avatar_url: avatarUrl,
        embeds: [embedMsg]
    }

    const url = `${webhookUrl}?wait=true`
    fetch(url, {
        method: 'post',
        body: JSON.stringify(requestBody),
        headers: { 'Content-Type': 'application/json' }
    })
        .then(res => res.json())
        .then(data => core.info(JSON.stringify(data)))
        .catch(err => core.info(err))
}

run()
    .then(() => {core.info('Action completed successfully')})
    .catch(err => {core.setFailed(err.message)})