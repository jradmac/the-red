"""Battle simulator: plays thousands of fights with the real battle rules
(scripts/battle.gd) to tune creature stats. python3 tools/battle_sim.py"""
import random, re, sys, statistics as st
from pathlib import Path
src = (Path(__file__).resolve().parent.parent / 'scripts' / 'creature_data.gd').read_text()
TYPES = {}
for kind in ("insect", "demon"):
    block = src.split('"%s": [' % kind)[1].split('],\n\t"')[0] if kind == "insect" else src.split('"demon": [')[1].split(']\n}')[0]
    TYPES[kind] = []
    for m in re.finditer(r'"atk": \[(\d+), \d+\], "def": \[(\d+), \d+\], "hp": (\d+).*?"nature": "(\w+)"', block):
        TYPES[kind].append(dict(atk=int(m[1]), df=int(m[2]), hp=int(m[3]), nature=m[4]))

def enemy_choice(nat, last_you, them_last, hp, max_hp, rng):
    w = [50, 30, 20]
    if nat == "bold": w = [65, 15, 20]
    elif nat == "timid": w = [25, 55, 20]
    elif nat == "mirror":
        if last_you in ("attack", "defend", "dodge") and rng.random() < 0.8: return last_you
    elif nat == "contrary":
        if last_you and rng.random() < 0.8:
            if last_you == "attack": return "defend" if rng.random() < 0.6 else "dodge"
            return "attack"
    elif nat == "alternate":
        if them_last and rng.random() < 0.85:
            if them_last == "attack": return "defend" if rng.random() < 0.5 else "dodge"
            return "attack"
    elif nat == "desperate":
        w = [70, 5, 25] if hp * 2 <= max_hp else [30, 50, 20]
    elif nat == "punisher":
        if last_you in ("defend", "dodge") and rng.random() < 0.85: return "attack"
        w = [20, 50, 30]
    r = rng.random() * sum(w)
    return "attack" if r < w[0] else ("defend" if r < w[0] + w[1] else "dodge")

def prior(nat, last_you, them_last, hp, mx):
    """P(attack), P(defend), P(dodge) as a player who knows the nature would guess."""
    if nat == "bold": return [.65, .15, .2]
    if nat == "timid": return [.25, .55, .2]
    if nat == "mirror":
        if last_you in ("attack", "defend", "dodge"):
            b = [.1, .06, .04]; i = ["attack", "defend", "dodge"].index(last_you); b[i] += .8; return b
        return [.5, .3, .2]
    if nat == "contrary":
        if last_you == "attack": return [.1, .48 + .06, .32 + .04]
        if last_you: return [.8 + .1, .06, .04]
        return [.5, .3, .2]
    if nat == "alternate":
        if them_last == "attack": return [.075, .425 + .045, .425 + .03]
        if them_last: return [.85 + .075, .045, .03]
        return [.5, .3, .2]
    if nat == "desperate": return [.7, .05, .25] if hp * 2 <= mx else [.3, .5, .2]
    if nat == "punisher":
        if last_you in ("defend", "dodge"): return [.85 + .03, .075, .045]
        return [.2, .5, .3]
    return [.5, .3, .2]

def smart_pick(e, patk, pdef, last_you, them_last, hp, mx, tell, rng):
    pr = prior(e["nature"], last_you, them_last, hp, mx)
    if tell:
        ti = ["attack", "defend", "dodge"].index(tell)
        like = [0.8 if i == ti else 0.1 for i in range(3)]
        pr = [pr[i] * (0.65 * like[i]) for i in range(3)]
    tot = sum(pr); pa, pd, pg = [x / tot for x in pr]
    edef = e["df"]
    def ev(you):
        dealt = taken = 0
        if you == "attack":
            dealt = pa * patk + pd * max(patk - edef, 0) + pg * 0.5 * patk
            taken = pa * e["atk"]
        elif you == "defend":
            taken = pa * max(e["atk"] - pdef, 0)
        else:
            taken = pa * 0.5 * e["atk"]
        return dealt - 1.3 * taken
    return max(("attack", "defend", "dodge"), key=ev)

def fight(patk, pdef, e, rng, skill=0.8):
    hp = e["hp"]; mx = hp; dmg = 0; rounds = 0; last_you = ""; them_last = ""
    while hp > 0 and rounds < 40:
        rounds += 1
        them = enemy_choice(e["nature"], last_you, them_last, hp, mx, rng)
        tell = None
        if rng.random() < 0.65:
            tell = them if rng.random() < 0.8 else rng.choice([m for m in ("attack", "defend", "dodge") if m != them])
        # the player: knows the nature, reads the tell, picks the best odds
        you = smart_pick(e, patk, pdef, last_you, them_last, hp, mx, tell, rng) if rng.random() < skill else "attack"
        edef = e["df"]
        if you == "attack":
            if them == "attack": hp -= patk
            elif them == "defend": hp -= max(patk - edef, 0)
            elif them == "dodge": hp -= 0 if rng.random() < 0.5 else patk
        if them == "attack":
            if you == "attack": dmg += e["atk"]
            elif you == "defend": dmg += max(e["atk"] - pdef, 0)
            elif you == "dodge": dmg += 0 if rng.random() < 0.5 else e["atk"]
        last_you, them_last = you, them
    return dmg, rounds

def gear(p):
    """The best weapon / armor a player has found by depth p (club early, then
    hatchet, mace, grave blade; vest .. plate; blessings deeper)."""
    return round(3 + 3 * p + 1.5 * p), round(1 + 3.5 * p + 1.0 * p)

def make_enemy(kind, t, p, sc):
    b = TYPES[kind][t]
    s = sc[kind]
    return dict(atk=b["atk"] + round(p * s["atk"]), df=b["df"] + round(p * s["def"]),
                hp=round(b["hp"] * (s["hp_base"] + p * s["hp"])), nature=b["nature"])

def table(sc, label, demon_share=(0.12, 0.6), n=600):
    rng = random.Random(1)
    print(label)
    out = []
    for p in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0):
        patk, pdef = gear(p)
        dm, rd = [], []
        for i in range(n):
            kind = "demon" if rng.random() < demon_share[0] + (demon_share[1] - demon_share[0]) * p else "insect"
            opts = TYPES[kind]
            tough = rng.random() < 0.1 + 0.75 * p
            t = rng.randrange(len(opts) // 2) * 2 + (1 if tough else 0)
            e = make_enemy(kind, t, p, sc)
            if kind == "demon": e["df"] = max(e["df"] - 1, 0)
            d, r = fight(patk, pdef, e, rng)
            dm.append(d); rd.append(r)
        out.append((p, st.mean(dm), st.mean(rd)))
        print("  p=%.1f gear atk %d def %d | damage/fight %.2f  rounds %.2f  (worst 10%% %.1f)" % (
            p, patk, pdef, st.mean(dm), st.mean(rd), sorted(dm)[int(n * 0.9)]))
    return out

# Keep in step with Enemies.SCALING (scripts/enemies.gd).
SCALING = {"insect": {"atk": 1, "def": 3, "hp": 1.0, "hp_base": 1.6},
           "demon": {"atk": 2, "def": 2, "hp": 1.0, "hp_base": 1.2}}
if __name__ == "__main__":
    table(SCALING, "Enemies.SCALING vs a player who reads the tells (damage in hearts):", n=1500)
