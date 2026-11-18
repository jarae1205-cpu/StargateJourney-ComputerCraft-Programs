package io.github.stargatecommand.chevron7;

/**
 * How a gate dials. Both kinds share the ring, the network and travel; how a gate looks is its
 * GateLook. The Stargate Network gate dials letters on nine chevrons.
 */
public enum GateStyle
{
	/** The gate of the films and SG-1: 39 symbols, seven chevrons lock. */
	CLASSIC(39, 7),
	/** In the style of SGCraft's Stargate Network: a ring of 36 letters and digits, nine chevrons lock. */
	NETWORK(36, 9);

	private static final int[] SEVEN = {1, 2, 3, 6, 7, 8, 0};
	private static final int[] NINE = {1, 2, 3, 6, 7, 8, 4, 5, 0};

	/** Symbols on the ring. */
	public final int symbols;
	/** Chevrons locked by a full dial. */
	public final int chevrons;

	GateStyle(int symbols, int chevrons)
	{
		this.symbols = symbols;
		this.chevrons = chevrons;
	}

	/** Dials letters (Stargate Network) instead of symbols and a point of origin. */
	public boolean letters()
	{
		return this == NETWORK;
	}

	/** Degrees between two symbols on the ring. */
	public float step()
	{
		return 360.0F / symbols;
	}

	/** Chevron slots (every 40 degrees, 0 at the top) in the order they light; the top one locks last. */
	public int[] chevronOrder()
	{
		return chevrons == 9 ? NINE : SEVEN;
	}
}
