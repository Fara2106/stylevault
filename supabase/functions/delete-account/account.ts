// Logica pura della cancellazione account (testata in account_test.ts).

/** Una voce di /storage/v1/object/list: le cartelle hanno id null. */
export type ListEntry = { name: string; id: string | null };
/** Elenca una pagina di `prefix` a partire da `offset`. */
export type ListFn = (prefix: string, offset: number) => Promise<ListEntry[]>;

/** Il corpo della richiesta deve dire esplicitamente { confirm: "DELETE" }. */
export function isConfirmed(body: unknown): boolean {
  return (body as { confirm?: unknown } | null)?.confirm === 'DELETE';
}

/**
 * Tutti i file dell'utente in un bucket: i percorsi iniziano con `<uid>/`
 * (le policy dello storage lo impongono). Scende nelle sottocartelle e
 * scorre le pagine. Un id vuoto o con "/" è rifiutato: non si elenca mai la
 * radice del bucket, che contiene i file di tutti.
 */
export async function listUserFiles(list: ListFn, userId: string, pageSize = 1000): Promise<string[]> {
  if (!userId || userId.includes('/')) throw new Error('user-id-invalid');
  const files: string[] = [];
  const pending = [`${userId}/`];
  while (pending.length) {
    const prefix = pending.pop()!;
    for (let offset = 0; ; offset += pageSize) {
      const page = await list(prefix, offset);
      for (const entry of page) {
        if (entry.id === null) pending.push(`${prefix}${entry.name}/`);
        else files.push(`${prefix}${entry.name}`);
      }
      if (page.length < pageSize) break;
    }
  }
  return files;
}

export function chunks<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}
