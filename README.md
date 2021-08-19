# PowerEdge-shutup

R2 update: now takes in account intake and exhaust temperatures!

## Requirements
- iDrac Entreprise (afaik it won't work with express)
- [IPMItool](https://github.com/ipmitool/ipmitool)
- G11*, G12 or G13** Dell Poweredge server

*See also [me/PowerEdge-IPMItools](https://github.com/White-Raven/PowerEdge-IPMItools) for other applications and resources.*

## What about it
Does what it says, depending on your environmental constraints, it might let you make your servers whisper-quiet, which 
- for an office or small business, might let you have a functionnal and capable server room without ACTUALLY having to have a proper server room with space and soundproofing,
- and for a small home setup or homelab might be a life and sleep saver


It's the "raw script" that can be almost used as is in a cron job, you're obviously free to use it and modify it.

I'ld just appreciate that if you itterate on it or send it somewhere, you could else reference the source or commit it here under a new file name*, or fork it.
(*to keep the original as-is, as an example of lazyness)

As of what you can do with these great little commands... well..

You can run them as a cron job, or create a loop, or add some calculations pulling data for the inlet/outlet to fine tune even more, but point is, lets you set your fan speed to bare minimum RPM depending of how warm or cool is your room and how hard you hit your servers.



## What if Linux hangs, and my server stops adjusting its fan speed?

For the sake of simplicity in this repo, I won't dive into the whole mess of scripts in own setup, BUT
but the script actually doesn't run on the server itself but on a Pi2 of which the sole purpose is to manage IPMI enabled machines' cooling, be a server to distribute UPS data/status, and answer pings.

- If the Pi hangs, when the server pings it, it won't get an answer, and the server will switch itself on auto fan mode, which is BIOS/Firmware managed.
The server can also change its curve when running some tasks/loads, in fact it goes through NetCat to tell the pie "now I need that" and the pie switches to an other set of fan curve for that server.

- If the server hangs... well it hanged, no biggie, the Pi keeps its cooling managed, since the IPMI would still pull accurate temps readings and would still answer the phone when the Pi tells it to do some stuff.
So yeah, bit more convoluted but it allows the servers to not be needing to be stable indefinitely to not risk to catch fire.

I simply haven't included all that because it's a lot more cumbersome and needs to be kinda adapted to each setup and set of needs, and I'm clearly not going to do that.


----------------
*_G11 seem to lack CPU temps in the data you can pull and rely on. Beware of the comments about it in the script and use the appropriate bits of code._

**_I was told it is also working on iDrac8 (G13), but that beyond iDrac update 3.30.30.30, Dell has modified/removed the ability to control the fans via IMPI._
