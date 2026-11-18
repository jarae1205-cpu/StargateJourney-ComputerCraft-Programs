package io.github.stargatecommand.chevron7;

import java.math.BigInteger;
import java.util.ArrayList;
import java.util.List;

import javax.annotation.Nullable;

/**
 * Letter addresses, written the way SGCraft writes them: nine letters and digits, "1KA0-9KT-HY".
 *
 * Every gate has one. It is another way of writing the gate's symbol address, so any gate can
 * dial any other in either form: the first six characters carry the six symbols, the last three
 * are a check, so a mistyped address is caught rather than reaching some other gate.
 */
public final class SGAddress
{
	private SGAddress() {}

	public static final String ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	public static final int LENGTH = 9;
	private static final int DATA = 6;
	private static final long DATA_RANGE = pow(36, DATA);
	private static final long CHECK_RANGE = pow(36, LENGTH - DATA);
	/** Six different symbols out of 1 to 38, in order. */
	private static final long ADDRESSES = arrangements(GateAddress.SYMBOLS - 1, GateAddress.LENGTH);
	// a fixed shuffle of the numbers below DATA_RANGE, so neighbouring addresses don't look alike;
	// MULTIPLIER shares no factor with 36, so the shuffle can be undone
	private static final long MULTIPLIER = 1_234_567_891L;
	private static final long OFFSET = 917_240_117L;
	private static final long INVERSE = BigInteger.valueOf(MULTIPLIER).modInverse(BigInteger.valueOf(DATA_RANGE)).longValue();

	private static long pow(int base, int exponent)
	{
		long result = 1;
		for(int i = 0; i < exponent; i++)
			result *= base;
		return result;
	}

	private static long arrangements(int n, int k)
	{
		long result = 1;
		for(int i = 0; i < k; i++)
			result *= n - i;
		return result;
	}

	/** The letter address of a symbol address, e.g. "1KA09KTHY"; null for an invalid address. */
	@Nullable
	public static String encode(int[] address)
	{
		if(!GateAddress.valid(address))
			return null;
		List<Integer> pool = pool();
		long rank = 0;
		for(int i = 0; i < GateAddress.LENGTH; i++)
		{
			int index = pool.indexOf(address[i]);
			rank = rank * pool.size() + index;
			pool.remove(index);
		}
		long data = Math.floorMod(rank * MULTIPLIER + OFFSET, DATA_RANGE);
		char[] out = new char[LENGTH];
		long d = data;
		for(int i = DATA - 1; i >= 0; i--)
		{
			out[i] = ALPHABET.charAt((int) (d % 36));
			d /= 36;
		}
		long c = check(data);
		for(int i = LENGTH - 1; i >= DATA; i--)
		{
			out[i] = ALPHABET.charAt((int) (c % 36));
			c /= 36;
		}
		return new String(out);
	}

	/** The symbol address written by a letter address; null if no gate can have it. Dashes and case don't matter. */
	@Nullable
	public static int[] decode(String text)
	{
		String letters = clean(text);
		if(letters.length() != LENGTH)
			return null;
		long data = 0, c = 0;
		for(int i = 0; i < LENGTH; i++)
		{
			int digit = ALPHABET.indexOf(letters.charAt(i));
			if(digit < 0)
				return null;
			if(i < DATA)
				data = data * 36 + digit;
			else
				c = c * 36 + digit;
		}
		if(c != check(data))
			return null;
		long rank = Math.floorMod(Math.floorMod(data - OFFSET, DATA_RANGE) * INVERSE, DATA_RANGE);
		if(rank >= ADDRESSES)
			return null;
		int[] digits = new int[GateAddress.LENGTH];
		for(int i = GateAddress.LENGTH - 1; i >= 0; i--)
		{
			int base = GateAddress.SYMBOLS - 1 - i;
			digits[i] = (int) (rank % base);
			rank /= base;
		}
		List<Integer> pool = pool();
		int[] address = new int[GateAddress.LENGTH];
		for(int i = 0; i < GateAddress.LENGTH; i++)
			address[i] = pool.remove(digits[i]);
		return address;
	}

	/** Upper case, without dashes or spaces. */
	public static String clean(String text)
	{
		return text == null ? "" : text.toUpperCase(java.util.Locale.ROOT).replaceAll("[\\s\\-]", "");
	}

	/** Nine letters and digits, whether or not a gate has them. */
	public static boolean wellFormed(String text)
	{
		String letters = clean(text);
		if(letters.length() != LENGTH)
			return false;
		for(int i = 0; i < LENGTH; i++)
			if(ALPHABET.indexOf(letters.charAt(i)) < 0)
				return false;
		return true;
	}

	/** "1KA0-9KT-HY" */
	public static String format(@Nullable String letters)
	{
		String s = letters == null ? "" : clean(letters);
		if(s.length() != LENGTH)
			return s.isEmpty() ? "-" : s;
		return s.substring(0, 4) + "-" + s.substring(4, 7) + "-" + s.substring(7);
	}

	/** The formatted letter address of a symbol address, or "-". */
	public static String formatOf(int[] address)
	{
		return format(encode(address));
	}

	/** The positions on a letter ring of each character, e.g. "AB" -> {0, 1}. */
	public static List<Integer> positions(String letters)
	{
		String s = clean(letters);
		List<Integer> out = new ArrayList<>(s.length());
		for(int i = 0; i < s.length(); i++)
			out.add(ALPHABET.indexOf(s.charAt(i)));
		return out;
	}

	/** The characters at these positions of a letter ring. */
	public static String letters(List<Integer> positions)
	{
		StringBuilder builder = new StringBuilder(positions.size());
		for(int p : positions)
			builder.append(p >= 0 && p < ALPHABET.length() ? ALPHABET.charAt(p) : '?');
		return builder.toString();
	}

	private static List<Integer> pool()
	{
		List<Integer> pool = new ArrayList<>(GateAddress.SYMBOLS - 1);
		for(int s = 1; s < GateAddress.SYMBOLS; s++)
			pool.add(s);
		return pool;
	}

	/** Three check characters' worth of a well-mixed hash. */
	private static long check(long data)
	{
		long z = data + 0x9E3779B97F4A7C15L;
		z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9L;
		z = (z ^ (z >>> 27)) * 0x94D049BB133111EBL;
		z = z ^ (z >>> 31);
		return Math.floorMod(z, CHECK_RANGE);
	}
}
