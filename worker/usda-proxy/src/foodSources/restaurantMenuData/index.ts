import { burgerKing } from './burgerKing'
import { chickFilA } from './chickFilA'
import { chipotle } from './chipotle'
import { dominos } from './dominos'
import { dunkin } from './dunkin'
import { fiveGuys } from './fiveGuys'
import { mcdonalds } from './mcdonalds'
import { panera } from './panera'
import { pandaExpress } from './pandaExpress'
import { popeyes } from './popeyes'
import { raisingCanes } from './raisingCanes'
import { starbucks } from './starbucks'
import { tacoBell } from './tacoBell'
import type { ChainMenu } from './types'

export type { ChainMenu, MenuRow } from './types'

export interface ChainEntry {
  id: string
  menu: ChainMenu
  /** Normalized spellings, without trailing "s", that name this chain in a query. */
  aliases: string[]
  /** Words that describe a built meal; they are satisfied by component rows. */
  buildWords?: string[]
}

export const chainEntries: ChainEntry[] = [
  { id: 'chickFilA', menu: chickFilA, aliases: ['chickfila', 'chikfila', 'chickfilla', 'chikfilla', 'cfa'] },
  { id: 'mcdonalds', menu: mcdonalds, aliases: ['mcdonald', 'mcd', 'mickeyd'] },
  {
    id: 'chipotle',
    menu: chipotle,
    aliases: ['chipotle', 'chipolte'],
    buildWords: ['burrito', 'bowl', 'salad', 'taco', 'quesadilla'],
  },
  { id: 'starbucks', menu: starbucks, aliases: ['starbuck', 'sbux'] },
  { id: 'tacoBell', menu: tacoBell, aliases: ['tacobell'] },
  { id: 'pandaExpress', menu: pandaExpress, aliases: ['pandaexpres', 'panda'] },
  { id: 'burgerKing', menu: burgerKing, aliases: ['burgerking', 'bk'] },
  { id: 'popeyes', menu: popeyes, aliases: ['popeye'] },
  { id: 'raisingCanes', menu: raisingCanes, aliases: ['raisingcane', 'raisingcanes', 'cane'] },
  {
    id: 'fiveGuys',
    menu: fiveGuys,
    aliases: ['fiveguy'],
    buildWords: ['burger', 'hamburger', 'cheeseburger', 'sandwich', 'dog'],
  },
  { id: 'dunkin', menu: dunkin, aliases: ['dunkindonut', 'dunkindonuts'] },
  { id: 'dominos', menu: dominos, aliases: ['domino'] },
  { id: 'panera', menu: panera, aliases: ['panerabread', 'panera'] },
]
