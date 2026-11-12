package io.github.stargatecommand.chevron7;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import javax.annotation.Nullable;

import net.minecraft.util.RandomSource;

/**
 * Gate addresses: six different symbols from 1 to 38. Symbol 0 is the point of origin,
 * dialed last to open the wormhole.
 */
public final class GateAddress
{
	private GateAddress() {}

	public static final int SYMBOLS = 39;
	public static final int LENGTH = 6;
	public static final int POINT_OF_ORIGIN = 0;

	public static int[] random(RandomSource random)
	{
		List<Integer> pool = new ArrayList<>();
		for(int s = 1; s < SYMBOLS; s++)
			pool.add(s);
		int[] address = new int[LENGTH];
		for(int i = 0; i < LENGTH; i++)
			address[i] = pool.remove(random.nextInt(pool.size()));
		return address;
	}

	public static boolean valid(int[] address)
	{
		if(address == null || address.length != LENGTH)
			return false;
		for(int i = 0; i < LENGTH; i++)
		{
			if(address[i] < 1 || address[i] >= SYMBOLS)
				return false;
			for(int j = 0; j < i; j++)
				if(address[i] == address[j])
					return false;
		}
		return true;
	}

	/** "-12-5-30-21-7-1-" */
	public static String format(int[] address)
	{
		if(address == null || address.length == 0)
			return "-";
		StringBuilder builder = new StringBuilder("-");
		for(int symbol : address)
			builder.append(symbol).append('-');
		return builder.toString();
	}

	public static String key(int[] address)
	{
		return format(address);
	}

	/** Reads "-12-5-30-21-7-1-", "12-5-30-21-7-1" or "12 5 30 21 7 1"; a trailing point of origin is ignored. */
	@Nullable
	public static int[] parse(String text)
	{
		String[] parts = text.trim().split("[-\\s,]+");
		List<Integer> symbols = new ArrayList<>();
		for(String part : parts)
		{
			if(part.isEmpty())
				continue;
			try
			{
				symbols.add(Integer.parseInt(part));
			}
			catch(NumberFormatException e)
			{
				return null;
			}
		}
		if(symbols.size() == LENGTH + 1 && symbols.get(LENGTH) == POINT_OF_ORIGIN)
			symbols.remove(LENGTH);
		int[] address = symbols.stream().mapToInt(Integer::intValue).toArray();
		return valid(address) ? address : null;
	}

	public static List<Integer> list(int[] address)
	{
		List<Integer> list = new ArrayList<>(address.length);
		for(int symbol : address)
			list.add(symbol);
		return list;
	}

	public static boolean same(int[] a, int[] b)
	{
		return Arrays.equals(a, b);
	}
}
