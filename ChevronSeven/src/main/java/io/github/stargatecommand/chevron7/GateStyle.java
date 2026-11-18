package io.github.stargatecommand.chevron7;

/**
 * The kinds of gate. They share the ring, the network and travel; they differ in looks,
 * and the Stargate Network gate dials letters on nine chevrons.
 */
public enum GateStyle
{
	/** The gate of the films and SG-1: 39 symbols, seven chevrons lock. */
	CLASSIC("", 39, 7),
	/** The cartoon gate of the animated series Stargate Infinity: same dialing, its own look. */
	INFINITY("chevron7:infinity", 39, 7),
	/** In the style of SGCraft's Stargate Network: a ring of 36 letters and digits, nine chevrons lock. */
	NETWORK("chevron7:stargate_network", 36, 9);

	private static final int[] SEVEN = {1, 2, 3, 6, 7, 8, 0};
	private static final int[] NINE = {1, 2, 3, 6, 7, 8, 4, 5, 0};

	/** What a computer reads as the gate's variant; the Gate Room picks its look from it. */
	public final String variant;
	/** Symbols on the ring. */
	public final int symbols;
	/** Chevrons locked by a full dial. */
	public final int chevrons;

	GateStyle(String variant, int symbols, int chevrons)
	{
		this.variant = variant;
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
