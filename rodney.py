import discord
import os
import threading
import select
import urllib.parse
import urllib.request
import aiohttp
import logging
import random
from lxml import html, etree

client = discord.Client()

verbs = [ 'killed', 'murked', 'ruined', 'slapped too hard', 'thronked', 'fucked up', 'resolved WONTFIX', 'rekt', 'made to rethink their life', 'shredded', u'd\u0339\u0345o\u0489\u032d\u0325\u032f\u0359\u0324\u033bo\u0335\u0356\u033c\u033b\u032b\u0330\u0354\u032fm\u0358\u034e\u0324 \u0336\u0319\u033c\u033bm\u0358\u032f\u031f\u031f\u032b\u0330e\u0326\u032a\u031e\u0325\u0329\u033c\u032dta\u0339\u0333\u0330\u032a\u0323\u033a\u031el\u0329\u032f\u033a\u0318\u032d\u032d\u0353ed' ]

zalgo_down = [
    u'\u0316', u'\u0317', u'\u0318', u'\u0319', 
    u'\u031c', u'\u031d', u'\u031e', u'\u031f', 
    u'\u0320', u'\u0324', u'\u0325', u'\u0326', 
    u'\u0329', u'\u032a', u'\u032b', u'\u032c', 
    u'\u032d', u'\u032e', u'\u032f', u'\u0330', 
    u'\u0331', u'\u0332', u'\u0333', u'\u0339', 
    u'\u033a', u'\u033b', u'\u033c', u'\u0345', 
    u'\u0347', u'\u0348', u'\u0349', u'\u034d', 
    u'\u034e', u'\u0353', u'\u0354', u'\u0355', 
    u'\u0356', u'\u0359', u'\u035a', u'\u0323',
]

zalgo_mid = [
    u'\u0315', u'\u031b', u'\u0340', u'\u0341', 
    u'\u0358', u'\u0321', u'\u0322', u'\u0327', 
    u'\u0328', u'\u0334', u'\u0335', u'\u0336', 
    u'\u034f', u'\u035c', u'\u035d', u'\u035e', 
    u'\u035f', u'\u0360', u'\u0362', u'\u0338', 
    u'\u0337', u'\u0361', u'\u0489' 
]

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
        print(fdict["death"])
        deathstr = fdict["death"].replace('killed', random.choice(verbs))
        print(deathstr)
        whilestr = ""
        if "while" in fdict:
            whilestr = " while " + fdict["while"]
        deathline = "`%s (%s %s %s %s), %s%s on level %s after %s turns, with %s points`" % (fdict["name"], fdict["role"], fdict["race"], fdict["gender"], fdict["align"], deathstr, whilestr, fdict["deathlev"], fdict["turns"], fdict["points"])
        print(deathline)
        client.loop.create_task(post_message(discord.Object('253557833352609803'), deathline))
        print('[FIFO] posted line')
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
    await client.change_presence(game=discord.Game(name="NetHack 3.6.1"))
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
    elif message.content.startswith('!zalgo'):
        await client.send_typing(message.channel)
        out = ""
        for c in " ".join(message.content.split(" ")[1:]):
            out = out + c
            for i in range(random.randint(0,2)):
                out = out + random.choice(zalgo_mid)
            for i in range(random.randint(2,5)):
                out = out + random.choice(zalgo_down)
        await client.send_message(message.channel, out)
            
        

@client.event
async def post_message(channel, message):
    await client.send_message(channel, message)
    
#logging.basicConfig(level=logging.DEBUG)        
client.loop.run_in_executor(None, fifo_reader, None)
client.run("NDE2NDIyNjc1NDI3MDk4NjQ0.DbRe-A.IkvY8ckx2o0KMcmWLG7GWVf3XPM")
