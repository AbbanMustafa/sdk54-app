import { useState, useEffect } from 'react';
import { StyleSheet, FlatList, View } from 'react-native';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { IconSymbol } from '@/components/ui/icon-symbol';

interface Song {
  title: string;
  artist: string;
  timestamp: number;
}

export default function LibraryScreen() {
  const [history, setHistory] = useState<Song[]>([]);

  useEffect(() => {
    loadHistory();
  }, []);

  const loadHistory = async () => {
    // In a real app, load from AsyncStorage
    // For now, show empty state
    setHistory([]);
  };

  const renderSongItem = ({ item }: { item: Song }) => {
    const date = new Date(item.timestamp);
    const timeAgo = getTimeAgo(date);

    return (
      <ThemedView style={styles.songItem}>
        <View style={styles.songIcon}>
          <IconSymbol size={24} name="music.note" color="#0066FF" />
        </View>
        <View style={styles.songInfo}>
          <ThemedText style={styles.songTitle}>{item.title}</ThemedText>
          <ThemedText style={styles.songArtist}>{item.artist}</ThemedText>
        </View>
        <ThemedText style={styles.songTime}>{timeAgo}</ThemedText>
      </ThemedView>
    );
  };

  const getTimeAgo = (date: Date): string => {
    const seconds = Math.floor((Date.now() - date.getTime()) / 1000);

    if (seconds < 60) return 'Just now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return `${Math.floor(seconds / 86400)}d ago`;
  };

  return (
    <ThemedView style={styles.container}>
      <ThemedView style={styles.header}>
        <ThemedText type="title" style={styles.headerTitle}>
          Library
        </ThemedText>
      </ThemedView>

      {history.length === 0 ? (
        <View style={styles.emptyState}>
          <IconSymbol size={80} name="music.note.list" color="#999" />
          <ThemedText style={styles.emptyTitle}>No songs yet</ThemedText>
          <ThemedText style={styles.emptyText}>
            Songs you identify will appear here
          </ThemedText>
        </View>
      ) : (
        <FlatList
          data={history}
          renderItem={renderSongItem}
          keyExtractor={(item, index) => `${item.timestamp}-${index}`}
          contentContainerStyle={styles.listContainer}
        />
      )}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  headerTitle: {
    fontSize: 34,
    fontWeight: 'bold',
  },
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
  },
  emptyTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    marginTop: 20,
    marginBottom: 8,
  },
  emptyText: {
    fontSize: 16,
    opacity: 0.6,
    textAlign: 'center',
  },
  listContainer: {
    paddingHorizontal: 20,
  },
  songItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(0, 0, 0, 0.1)',
  },
  songIcon: {
    width: 48,
    height: 48,
    borderRadius: 8,
    backgroundColor: 'rgba(0, 102, 255, 0.1)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  songInfo: {
    flex: 1,
  },
  songTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  songArtist: {
    fontSize: 14,
    opacity: 0.6,
  },
  songTime: {
    fontSize: 12,
    opacity: 0.5,
  },
});
