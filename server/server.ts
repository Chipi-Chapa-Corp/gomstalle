// server.ts
import { Hono } from 'hono'
import { serve } from '@hono/node-server'
import { createNodeWebSocket } from '@hono/node-ws'
import { WSContext } from 'hono/ws'

type Room = {
  id: string
  host: { ip: string; port: number }
  mode: string; ver: string; cap: number; cur: number
  token: string; lastHb: number
  players: Map<number, { joinedAt: number }>
}

const app = new Hono()
const { injectWebSocket, upgradeWebSocket } = createNodeWebSocket({ app })

const rooms = new Map<string, Room>()
const clients = new Set<WSContext<WebSocket>>() // <- store WSContext

const now = () => Date.now()
const listPayload = () => JSON.stringify({
  type: 'ROOMS',
  rooms: [...rooms.values()].map(r => ({
    id: r.id, host: r.host, mode: r.mode, ver: r.ver, cap: r.cap, cur: r.cur
  })),
})

const broadcastRooms = () => {
  const payload = listPayload()
  for (const c of clients) {
    try { c.send(payload) } catch { /* ignore */ }
  }
}

const prune = () => {
  const t = now()
  let changed = false
  for (const [id, r] of rooms) if (t - r.lastHb > 12_000) { rooms.delete(id); changed = true; console.log("PRUNED", id) }
  if (changed) broadcastRooms()
}
setInterval(prune, 1000)

let lastNetId = 1

app.get('/ws', upgradeWebSocket(() => ({
  onOpen: (_evt, ws) => {
    clients.add(ws)                            // <- WSContext
    ws.send(JSON.stringify({ type: 'HELLO' }))
    ws.send(listPayload())                     // initial list
  },
  onClose: (_evt, ws) => {
    clients.delete(ws)
  },
  onMessage: (evt, ws) => {
    let m: any
    try { m = JSON.parse(String(evt.data)) } catch { return }

    switch (m.type) {
      case 'CREATE': {
        const id = Math.random().toString(36).slice(2, 8)
        const token = Math.random().toString(36).slice(2) + now()
        const players = new Map<number, { joinedAt: number }>()
        const hostNetId = lastNetId++
        players.set(hostNetId, { joinedAt: now() })
        rooms.set(id, {
          id, host: m.host, mode: m.mode, ver: m.ver, cap: m.cap ?? 8, cur: 1,
          token, lastHb: now(), players
        })
        ws.send(JSON.stringify({ type: 'CREATED', room_id: id, token, net_id: hostNetId }))
        broadcastRooms()
        console.log("CREATED", id, token)
        break
      }
      case 'HEARTBEAT': {
        const r = rooms.get(m.room_id)
        if (r && r.token === m.token) r.lastHb = now()
        console.log("HEARTBEAT", m.room_id, m.token)
        break
      }
      case 'CLOSE': {
        const r = rooms.get(m.room_id)
        if (r && r.token === m.token) { rooms.delete(m.room_id); broadcastRooms() }
        console.log("CLOSED", m.room_id, m.token)
        break
      }
      case 'JOIN': {
        const r = rooms.get(m.room_id)
        if (!r) { ws.send(JSON.stringify({ type: 'JOIN_REPLY', ok: false, net_id: -1 })); break }
        if (r.cur >= r.cap) { ws.send(JSON.stringify({ type: 'JOIN_REPLY', ok: false, net_id: -1 })); break }
        const netId = lastNetId++
        r.players.set(netId, { joinedAt: now() })
        r.cur = r.players.size
        ws.send(JSON.stringify({ type: 'JOIN_REPLY', ok: true, net_id: netId, host: r.host }))
        broadcastRooms()
        console.log("JOIN", m.room_id, m.token)
       break
      }
    }
  },
})))

const server = serve({ fetch: app.fetch, port: 7777 })
injectWebSocket(server)
