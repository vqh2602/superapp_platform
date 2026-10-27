import { createHash, randomBytes, scrypt, timingSafeEqual } from 'crypto';

const SCRYPT_OPTIONS = { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
export const digest = (value: string) => createHash('sha256').update(value).digest('hex');
export const secret = (prefix: string) => `${prefix}_${randomBytes(32).toString('base64url')}`;
export const pkceChallenge = (verifier: string) => createHash('sha256').update(verifier).digest('base64url');
export const miniAppOpenId = (userId: string, appId: string) => 'open_' + digest(`${userId}:${appId}`);

function derive(password: string, salt: string): Promise<Buffer> {
  return new Promise((resolve, reject) => scrypt(password, salt, 64, SCRYPT_OPTIONS,
    (error, value) => error ? reject(error) : resolve(value)));
}
export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16).toString('hex');
  return `scrypt$${salt}$${(await derive(password, salt)).toString('hex')}`;
}
export async function verifyPassword(password: string, hash: string): Promise<boolean> {
  const [algorithm, salt, expected] = hash.split('$');
  if (algorithm !== 'scrypt' || !/^[a-f0-9]{32}$/.test(salt) || !/^[a-f0-9]{128}$/.test(expected)) return false;
  return timingSafeEqual(await derive(password, salt), Buffer.from(expected, 'hex'));
}
