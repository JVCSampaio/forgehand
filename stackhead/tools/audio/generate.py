"""Original cartoon audio. No third-party recordings. PCM16 mono / 44100Hz."""
import math, random, wave, struct, json
from pathlib import Path
SR = 44100
OUT = Path(__file__).resolve().parents[2] / 'assets' / 'audio'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(731)
def tone(duration, start, end=None, kind='sine', volume=0.45):
    result=[]; phase=0
    for i in range(round(duration*SR)):
        t=i/SR; u=t/duration
        freq=start + ((end if end is not None else start)-start)*u
        phase += 2*math.pi*freq/SR
        signal=math.sin(phase)
        if kind=='honk': signal=(signal+0.45*math.sin(phase*3)+0.2*math.sin(phase*5))/1.65
        if kind=='noise': signal=0.25*signal+0.5*rng.uniform(-1,1)
        if kind=='boing': signal=math.sin(phase+3*math.sin(2*math.pi*18*t)*math.exp(-5*t))
        envelope=min(1,t/0.008)*min(1,(duration-t)/0.04)*math.exp(-u*(0.4 if kind=='honk' else 2.5))
        result.append(signal*envelope*volume)
    return result
def phrase(notes, beat=.13, kind='sine'):
    out=[]
    for n in notes: out += tone(beat,n,kind=kind)+[0.] * round(.025*SR)
    return out
clips={
 'Pickup':tone(.12,900,1500), 'Bank':phrase([523,659,784,1047],.12),
 'Upgrade':phrase([392,523,659,1047],.10), 'Error':tone(.19,220,110,volume=.3),
 'Collapse':phrase([392,370,349,220],.15,'honk')+tone(.3,150,60,'boing'),
 'Dash':tone(.2,300,1800,'noise',.35), 'Bump':tone(.22,180,65,'boing'),
 'Glue':tone(.35,280,580,'boing'), 'Rare':phrase([784,988,1175,1568],.10),
 'Meme':tone(.15,510,440,'honk')+[0.]*int(.075*SR)+tone(.23,580,390,'honk'),
 'Click':tone(.055,740,600,volume=.2), 'Wobble':tone(2,80,80,'noise',.12),
}
melody=[523,0,659,784,659,0,587,0,440,0,587,698,587,0,523,0,392,0,523,659,784,0,659,587,523,0,392,0,523,0,0,0]
clips['Music']=[]
for n in melody:
    clips['Music']+=tone(.21,n,kind='sine',volume=.3) if n else [0.]*round(.21*SR)
    clips['Music'] += [0.]*round(.04*SR)
manifest={}
for name,samples in clips.items():
    peak=max(abs(v) for v in samples)
    assert peak < .8
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR)
        f.writeframes(struct.pack('<'+'h'*len(samples),*(round(v*32767) for v in samples)))
    manifest[name]={'file':name+'.wav','seconds':round(len(samples)/SR,3),'peak_dbfs':round(20*math.log10(peak),1),'asset_id':0}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Generated {len(clips)} original clips in {OUT}')
