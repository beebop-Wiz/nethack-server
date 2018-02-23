import discord
import os
import threading
import select

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
            whilestr = " " + fdict["while"]
        deathline = "`%s (%s %s %s %s), %s%s on level %s after %s turns, with %s points`" % (fdict["name"], fdict["role"], fdict["race"], fdict["gender"], fdict["align"], fdict["death"], whilestr, fdict["deathlev"], fdict["turns"], fdict["points"])
        print(deathline)
        client.loop.create_task(post_message(discord.Object('253557833352609803'), deathline))
        fifo.close()

    
@client.event
async def on_ready():
    print("Connected")
    await client.change_presence(game=discord.Game(name="NetHack 3.6.0"))

@client.event
async def on_message(message):
    if message.content.startswith('!gt'):
        args = message.content.split(" ")
        await client.send_message(message.channel, "Go Team `" + args[1] + "`!")

@client.event
async def post_message(channel, message):
    await client.send_message(channel, message)
        
client.loop.run_in_executor(None, fifo_reader, None)
client.run("NDE2NDIyNjc1NDI3MDk4NjQ0.DXEPXw.pS-wFBlY_lBQ3HrxucoB8nCQa5Q")


    
