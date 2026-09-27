"""Validate the v2 design/data package; this is not a gameplay test runner."""
from __future__ import annotations
import argparse
import csv
import json
import re
import sys
from pathlib import Path
import check_data_core as core

def walk(obj):
    if isinstance(obj, dict):
        yield obj
        for value in obj.values():
            yield from walk(value)
    elif isinstance(obj, list):
        for value in obj:
            yield from walk(value)

def check_v2(data_dir, files, result):
    recs = lambda name: core.recs(files, f'content/{name}.json')
    creatures, islands, bosses = recs('creatures'), recs('islands'), recs('bosses')
    regular = [x for x in creatures if not x.get('is_boss')]
    boss_creatures = [x for x in creatures if x.get('is_boss')]
    if len(regular) != 15 or len(boss_creatures) != 3 or len(bosses) != 3 or len(islands) != 3:
        core.err('[SCOPE] Require 15 regular creatures, 3 boss creatures, 3 boss records, 3 islands')
    for island in islands:
        zones = island['zones']
        if not any(z['kind']=='player_spawn' for z in zones) or not any(z['kind']=='fishing' for z in zones) or not any(z['kind']=='boss_spot' for z in zones):
            core.err(f"[SCOPE] {island['id']} lacks playable spawn/fishing/boss zones")
        count = sum(island['id'] in c['island_ids'] for c in regular)
        if count != 5:
            core.err(f"[SCOPE] {island['id']} requires 5 ordinary species, got {count}")
        if island['order'] > 1 and not island['unlock']['requires_quest_ids']:
            core.err(f"[PROGRESS] {island['id']} has no unlock prerequisite")
    for creature in creatures:
        if creature['status'] not in ('slice','mvp'):
            core.err(f"[SCOPE] Required creature remains non-playable: {creature['id']}")
    reachable = {e['creature_id'] for table in recs('spawn_tables') for e in table['entries']}
    for creature in regular:
        if creature['id'] not in reachable:
            core.err(f"[SPAWN] No table contains {creature['id']}")

    hunger = files.get('content/hunger.json', {})
    item_ids = result['ids']['item']
    if hunger.get('offline_drain') is not False or hunger.get('damage_at_zero') != 0:
        core.err('[HUNGER] v2 requires no offline drain and no starvation damage')
    for food in hunger.get('foods', []):
        if food['item_id'] not in item_ids:
            core.err(f"[HUNGER] Unknown food {food['item_id']}")

    loot = files.get('content/lootboxes.json', {})
    cosmetics = {c['id']: c for c in loot.get('cosmetics', [])}
    if len(cosmetics) != len(loot.get('cosmetics', [])):
        core.err('[LOOT] Duplicate cosmetic ID')
    if loot.get('monetization_enabled') is not False or loot.get('real_money_trade') is not False:
        core.err('[LOOT] v2 first release must use free gameplay rewards')
    for cosmetic in cosmetics.values():
        if cosmetic['target_id'] not in result['ids']['tool'] | result['ids']['rod']:
            core.err(f"[LOOT] Unknown cosmetic target {cosmetic['target_id']}")
    for box in loot.get('records', []):
        if sum(e['weight'] for e in box['entries']) != box['total_weight']:
            core.err(f"[LOOT] Weight total mismatch {box['id']}")
        for entry in box['entries']:
            if entry['cosmetic_id'] not in cosmetics:
                core.err(f"[LOOT] Unknown reward {entry['cosmetic_id']}")

    registry = files.get('contracts/asset_registry.json', {}).get('assets', [])
    for a in registry:
        if '..' in Path(a['path'].replace('res://','')).parts:
            core.err(f"[ASSET] Traversal path {a['id']}")
    for rel, obj in files.items():
        if rel.startswith('content/'):
            for d in walk(obj):
                if {'min','max'} <= d.keys() and isinstance(d['min'], (int,float)) and isinstance(d['max'], (int,float)) and d['min'] > d['max']:
                    core.err(f'[RANGE] Inverted range in {rel}')
    with (data_dir/'loc/strings.csv').open(encoding='utf-8-sig',newline='') as f:
        for row in csv.DictReader(f):
            en = set(re.findall(r'\{[a-z_]+\}',row['en']))
            vi = set(re.findall(r'\{[a-z_]+\}',row['vi']))
            if en != vi: core.err(f"[LOC] Placeholder mismatch {row['keys']}")

    save = files.get('samples/account_save_example.json', {})
    banned = {'password','password_hash','access_token','refresh_token','recovery_code','service_key','rng_seed'}
    for obj in walk(save):
        if banned & obj.keys(): core.err('[SAVE] Server credentials/RNG must not be in client save view')
    # Check content and asset references in v2 server save without assuming the
    # precise structural nesting of owned items, progress or cosmetic lists.
    known = set().union(*result['ids'].values(), set(cosmetics))
    prefixes = ('cre_','bait_','rod_','tool_','item_','isl_','quest_','boss_','upg_','cos_','trick_','npc_')
    schema_field_names=set()
    for schema_path in (data_dir/'schemas').glob('*.json'):
        core.collect_names(json.loads(schema_path.read_text(encoding='utf-8')),schema_field_names)
    def check_saved_refs(x):
        if isinstance(x,dict):
            for k,v in x.items():
                if k.startswith(prefixes) and k not in known and k not in schema_field_names: core.err(f'[SAVE] Unknown key reference {k}')
                check_saved_refs(v)
        elif isinstance(x,list):
            for v in x: check_saved_refs(v)
        elif isinstance(x,str) and x.startswith(prefixes) and x not in known:
            core.err(f'[SAVE] Unknown value reference {x}')
    check_saved_refs(save)
    network=files.get('contracts/network_contract.json', {})
    if network.get('limits',{}).get('players_per_room') != 4:
        core.err('[NETWORK] First release requires maximum 4 players per room')
    balance=files['content/balance.json']
    if balance['physics']['ticks_per_second'] != network.get('limits',{}).get('simulation_hz'):
        core.err('[TIMING] Physics tick and network simulation_hz disagree')
    if balance['save']['autosave_interval_s'] != network.get('limits',{}).get('checkpoint_interval_s'):
        core.err('[TIMING] Autosave/checkpoint interval disagree')
    messages=network.get('messages',[])
    names=[m['name'] for m in messages]
    if len(names)!=len(set(names)): core.err('[NETWORK] Duplicate message name')
    embedded=[network.get('envelope',{}),network.get('authentication_payload',{})]
    embedded.extend(m.get('payload_schema',{}) for m in messages)
    for schema in embedded:
        try: core.Draft202012Validator.check_schema(schema)
        except Exception as exc: core.err(f'[NETWORK] Invalid embedded packet schema: {exc}')
    for message in messages:
        schema=message.get('payload_schema',{})
        if message.get('direction')=='client_to_server' and schema.get('additionalProperties') is not False:
            core.err(f"[NETWORK] Client payload must reject extra fields: {message['name']}")
    for event in files.get('contracts/events.json',{}).get('events',[]):
        names=[p['name'] for p in event['payload']]
        if len(names)!=len(set(names)): core.err(f"[EVENT] Duplicate payload field {event['name']}")
    return {'regular_species':len(regular),'bosses':len(bosses),'islands':len(islands),'assets':len(registry),'events':len(result['events']),'localization_keys':len(result['loc_keys'])}

def check_document_links(docs):
    for p in docs.rglob('*.md'):
        if 'references' in p.parts or p.name.startswith(('01_','02_','03_')): continue
        body=p.read_text(encoding='utf-8-sig')
        if '\ufffd' in body: core.err(f'[TEXT] Replacement character in {p.name}')
        if any(ord(c)<32 and c not in '\n\r\t' for c in body): core.err(f'[TEXT] Unexpected control character in {p.name}')
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)',body):
            target=target.strip('<>').split('#',1)[0]
            if not target or re.match(r'[a-z]+://',target): continue
            if not (p.parent/target).exists(): core.err(f'[LINK] {p.name}: {target}')

def check_registry_documents(docs,files):
    assets={a['id'] for a in files['contracts/asset_registry.json']['assets']}
    bible=docs/'06_ASSET_BIBLE.md'
    if not bible.exists(): core.err('[DOC] Missing asset bible'); return
    text=bible.read_text(encoding='utf-8')
    documented=set(re.findall(r'^\|\s*`?((?:mdl|mat|shd|tex|env|vfx|anm|ui|ico|fnt|sfx|mus|amb|vo)_[a-z0-9_]+)`?\s*\|',text,re.M))
    if documented != assets:
        core.err(f'[ASSET] Bible registry mismatch; missing={sorted(assets-documented)}, extra={sorted(documented-assets)}')
    # The distributed package has handoff next to its docs; project layout may
    # move it to the root, both locations are explicitly supported.
    candidates=[docs/'handoff/source_manifest.json',docs.parent/'handoff/source_manifest.json']
    manifest_path=next((p for p in candidates if p.exists()),None)
    if not manifest_path: core.err('[ASSET] Missing source manifest'); return
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    rows=manifest.get('assets',manifest.get('records',[]))
    ids=[r['asset_id'] for r in rows]
    if set(ids)!=assets or len(ids)!=len(set(ids)):
        core.err('[ASSET] Source manifest must contain each registered asset exactly once')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--docs')
    parser.add_argument('--data')
    args=parser.parse_args()
    docs,data=core.locate(args)
    required_docs=['00_START_HERE.md','04_GAME_DESIGN.md','05_ART_BIBLE.md','06_ASSET_BIBLE.md','07_TECHNICAL_DESIGN.md','08_SHARED_CONTRACTS.md','09_AGENT_TASKS.md','10_VALIDATION.md','11_DECISIONS_AND_UNKNOWNS.md','12_PREFLIGHT_AND_RESOURCES.md','13_CLAUDE_AUTOMATION.md','14_AI_ASSET_HANDOFF.md','15_DEPLOYMENT_AND_COST.md','16_CHANGELOG.md','17_VERIFIED_SOURCES.md']
    for name in required_docs:
        if not (docs/name).is_file(): core.err(f'[DOC] Required v2 file absent: {name}')
    core.FILE_SCHEMA.update({'content/hunger.json':'hunger','content/lootboxes.json':'lootboxes','contracts/network_contract.json':'network_contract','samples/account_save_example.json':'account_save'})
    for path in sorted(data.glob('*/*.json')):
        if path.parent.name=='schemas': continue
        rel=path.relative_to(data).as_posix()
        name={'save_example':'save','account_save_example':'account_save'}.get(path.stem,path.stem)
        core.FILE_SCHEMA[rel]=name
    for rel,name in core.FILE_SCHEMA.items():
        if not (data/rel).is_file(): core.err(f'[DATA] Required file absent: {rel}')
        if not (data/'schemas'/f'{name}.schema.json').exists():
            core.err(f'[SCHEMA] No schema for {rel}')
    if core.ERRORS:
        print('\n'.join(core.ERRORS)); return 1
    loaded=core.validate_schemas(data)
    if core.ERRORS:
        print('\n'.join(core.ERRORS)); return 1
    result=core.check_data(data,loaded['files'])
    stats=check_v2(data,loaded['files'],result)
    check_document_links(docs)
    check_registry_documents(docs,loaded['files'])
    for msg in core.ERRORS: print(msg)
    for msg in core.WARNINGS: print(msg)
    print(json.dumps({'errors':len(core.ERRORS),'warnings':len(core.WARNINGS),'json_files':len(loaded['files']),**stats},ensure_ascii=False))
    print('Scope: document/data validation only; no runtime, multiplayer, asset or deployment verification.')
    return 1 if core.ERRORS else 0

if __name__=='__main__':
    sys.exit(main())
