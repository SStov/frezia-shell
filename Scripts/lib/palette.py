"""
Palette extraction using K-means clustering with Smart Accent Hunting.
"""

import math
from .color import Color, rgb_to_lab, lab_to_rgb, lab_distance
from .hct import Cam16, Hct

# Type aliases
RGB = tuple[int, int, int]

def downsample_pixels(pixels: list[RGB], factor: int = 4) -> list[RGB]:
    """Downsample pixels for faster processing."""
    if factor <= 1:
        return pixels
    step = factor * factor
    return pixels[::step]


def kmeans_cluster(colors: list[RGB], k: int = 5, iterations: int = 10) -> list[tuple[RGB, RGB, int]]:
    """Perform K-means clustering on colors in Lab color space."""
    if len(colors) < k:
        unique = list(set(colors))
        return [(c, c, colors.count(c)) for c in unique[:k]]

    colors_lab = [rgb_to_lab(*c) for c in colors]

    sorted_indices = sorted(range(len(colors_lab)), key=lambda i: colors_lab[i][0])
    step = len(sorted_indices) // k
    centroids = [colors_lab[sorted_indices[i * step]] for i in range(k)]

    assignments = [0] * len(colors_lab)
    for _ in range(iterations):
        for idx, color in enumerate(colors_lab):
            min_dist = float('inf')
            min_cluster = 0
            for i, centroid in enumerate(centroids):
                dist = lab_distance(color, centroid)
                if dist < min_dist:
                    min_dist = dist
                    min_cluster = i
            assignments[idx] = min_cluster

        new_centroids = []
        for i in range(k):
            cluster_colors = [colors_lab[j] for j in range(len(colors_lab)) if assignments[j] == i]
            if cluster_colors:
                avg_L = sum(c[0] for c in cluster_colors) / len(cluster_colors)
                avg_a = sum(c[1] for c in cluster_colors) / len(cluster_colors)
                avg_b = sum(c[2] for c in cluster_colors) / len(cluster_colors)
                new_centroids.append((avg_L, avg_a, avg_b))
            else:
                new_centroids.append(centroids[i])
        centroids = new_centroids

    cluster_counts = [0] * k
    cluster_representatives: list[tuple[RGB, float]] = [(colors[0], float('inf'))] * k

    for idx, color_lab in enumerate(colors_lab):
        cluster_idx = assignments[idx]
        cluster_counts[cluster_idx] += 1
        dist = lab_distance(color_lab, centroids[cluster_idx])
        if dist < cluster_representatives[cluster_idx][1]:
            cluster_representatives[cluster_idx] = (colors[idx], dist)

    results = []
    for i in range(k):
        if cluster_counts[i] > 0:
            centroid_rgb = lab_to_rgb(*centroids[i])
            representative_rgb = cluster_representatives[i][0]
            results.append((centroid_rgb, representative_rgb, cluster_counts[i]))

    results.sort(key=lambda x: -x[2])
    return results


def extract_palette(pixels: list[RGB], k: int = 5, scoring: str = "smart") -> list[Color]:
    """
    Extract K dominant colors using Smart K-Means.
    Implements Noise Filtering, Accent Hunting (Volume * Chroma), and Hue Diversity.
    """
    sampled = downsample_pixels(pixels, factor=4)
    
    # 1. Noise Filtering: Ignore pitch black and blown-out whites
    filtered = []
    # Build a fast Hue histogram (36 buckets of 10 degrees) for Fix B
    hue_hist = [0] * 36
    
    for p in sampled:
        try:
            color = Color.from_rgb(p)
            h, _, l = color.to_hsl()
            if 0.15 <= l <= 0.85:
                filtered.append(p)
                bucket = int(h / 10.0) % 36
                hue_hist[bucket] += 1
        except Exception:
            continue
            
    if len(filtered) < k * 5:
        filtered = sampled  # Fallback if image is extremely dark/light
        # Rebuild histogram on fallback
        hue_hist = [0] * 36
        for p in filtered:
            try:
                h, _, _ = Color.from_rgb(p).to_hsl()
                hue_hist[int(h / 10.0) % 36] += 1
            except Exception:
                pass

    total_filtered = len(filtered)

    # Cluster
    cluster_count = 32
    clusters = kmeans_cluster(filtered, k=cluster_count)

    # Calculate average Chroma from clusters (Fix A)
    avg_chroma = 0.0
    chroma_samples = 0
    
    for centroid, _, count in clusters:
        try:
            hct = Color.from_rgb(centroid).to_hct()
            avg_chroma += hct.chroma * count
            chroma_samples += count
        except Exception:
            pass
            
    if chroma_samples > 0:
        avg_chroma /= chroma_samples
        
    # Dynamic Chroma Exponent
    chroma_exponent = 1.5
    if avg_chroma < 20:
        chroma_exponent = 1.0  # Muted image, calm down the boost
    elif avg_chroma < 35:
        chroma_exponent = 1.2  # Medium image, slight boost

    # 2. Smart Scoring: Volume * Chroma
    scored_clusters = []
    for centroid, rep, count in clusters:
        # Use centroid (averaged) to get smooth representative hue
        color = Color.from_rgb(centroid)
        try:
            hct = color.to_hct()
            
            # Fix B: Validate Hue market share (must be >= 1.5%)
            h, _, _ = color.to_hsl()
            bucket = int(h / 10.0) % 36
            # Check bucket and its two neighbors (30 degree window)
            market_share = (hue_hist[(bucket - 1) % 36] + hue_hist[bucket] + hue_hist[(bucket + 1) % 36]) / max(1, total_filtered)
            
            if market_share < 0.015:
                continue # Reject this cluster, it's a ghost/noise anomaly
            
            # Volume (count) * Saturation (Chroma)
            score = count * (hct.chroma ** chroma_exponent)
            scored_clusters.append((color, score))
        except Exception:
            pass

    scored_clusters.sort(key=lambda x: -x[1])
    
    # 3. Hue Diversity & Assembly
    final_colors = []
    if scored_clusters:
        # Primary is top scorer
        primary = scored_clusters[0][0]
        final_colors.append(primary)
        
        def hue_diff(h1, h2):
            diff = abs(h1 - h2)
            return min(diff, 360.0 - diff)
            
        # Collect distinct colors from remaining clusters
        for color, _ in scored_clusters[1:]:
            h, _, _ = color.to_hsl()
            # Check distance against ALL already selected colors
            if all(hue_diff(h, c.to_hsl()[0]) >= 45.0 for c in final_colors):
                final_colors.append(color)
            if len(final_colors) >= k:
                break
                
        # If we couldn't find enough distinct colors (e.g. monochromatic image), synthesize
        shifts = [180.0, 120.0, 240.0, 90.0, 270.0]
        shift_idx = 0
        while len(final_colors) < k:
            primary_h, primary_s, primary_l = primary.to_hsl()
            new_h = (primary_h + shifts[shift_idx % len(shifts)]) % 360.0
            final_colors.append(Color.from_hsl(new_h, primary_s, primary_l))
            shift_idx += 1
            
    else:
        # Extreme fallback
        final_colors = [Color.from_hex("#6750A4")] * k
        
    return final_colors[:k]


def find_error_color(palette: list[Color]) -> Color:
    """Find or generate an error color (red-biased)."""
    error_hues = [(345.0, 360.0), (0.0, 15.0)]
    
    for color in palette:
        try:
            h, s, _ = color.to_hsl()
            if s > 0.3 and any(low <= h <= high for low, high in error_hues):
                return color
        except Exception:
            continue
            
    return Color.from_hex("#FF5555")
