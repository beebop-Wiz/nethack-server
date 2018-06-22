import discord
import os
import threading
import select
import urllib.parse
import urllib.request
import aiohttp
import logging
from lxml import html, etree

client = discord.Client()

def fifo_reader(arg):
    print('[FIFO] Waiting for Discord connection...')
    client.wait_until_ready()
    print('[FIFO] Opening discord_fifo...')
    while True:
        fifo = open('discord_fifo', "r")
        print('[FIFO] recieved line')
        line = fifo.read()
        print(line)
        fields = line.split("\t")
        fdict = {}
        for f in fields:
            (key, value) = f.split("=")[0:2]
            fdict[key] = value
        print('[FIFO] parsed line')
        whilestr = ""
        if "while" in fdict:
            whilestr = " while " + fdict["while"]
        deathline = "`%s (%s %s %s %s), %s%s on level %s after %s turns, with %s points`" % (fdict["name"], fdict["role"], fdict["race"], fdict["gender"], fdict["align"], fdict["death"], whilestr, fdict["deathlev"], fdict["turns"], fdict["points"])
        print(deathline)
        client.loop.create_task(post_message(discord.Object('253557833352609803'), deathline))
        fifo.close()


async def wikiparse(channel, text, source):
    print('[WIKITEXT] Parsing...')
    tree = html.fromstring(text)
    title = tree.xpath('//*[@id="firstHeading"]/text()')[0]
    first_paragraph = tree.xpath('//div[@id="mw-content-text"]/p[1]')[0]
    text = "From <" + source + ">:\n"
    if first_paragraph.text is not None:
        text += first_paragraph.text
    for e in first_paragraph:
        if e.tag is 'b':
            text += '**' + e.text + '**'
        elif e.tag is 'a':
            text += e.text
        if e.tail is not None:
            text += e.tail
    client.loop.create_task(post_message(channel, text))
    
@client.event
async def on_ready():
    print("Connected")
    await client.change_presence(game=discord.Game(name="NetHack 3.6.0"))
    print("Successful API call")

@client.event
async def on_message(message):
    if message.content.startswith('!gt'):
        args = message.content.split(" ")
        await client.send_message(message.channel, "Go Team `" + args[1] + "`!")
    elif message.content.startswith('!wiki'):
        await client.send_typing(message.channel)
        args = message.content.split(" ")
        link = "https://www.nethackwiki.com/wiki/" + urllib.parse.quote(" ".join(args[1:]))
        async with aiohttp.ClientSession() as session:
            async with session.get(link) as response:
                if response.status == 200:
                    await wikiparse(message.channel, await response.text(), link)
                else:
                    await client.send_message(message.channel, "Error when retrieving " + link + ": HTTP " + str(response.status))
        

@client.event
async def post_message(channel, message):
    await client.send_message(channel, message)
    
#logging.basicConfig(level=logging.DEBUG)        
client.loop.run_in_executor(None, fifo_reader, None)
client.run("NDE2NDIyNjc1NDI3MDk4NjQ0.DbRe-A.IkvY8ckx2o0KMcmWLG7GWVf3XPM")
