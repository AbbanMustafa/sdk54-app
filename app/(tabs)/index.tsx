import { useState, useEffect } from 'react';
import { StyleSheet, TouchableOpacity, View, Animated } from 'react-native';
import { Audio } from 'expo-av';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useColorScheme } from '@/hooks/use-color-scheme';

export default function ShazamScreen() {
  const [isRecording, setIsRecording] = useState(false);
  const [recording, setRecording] = useState<Audio.Recording | null>(null);
  const [hasPermission, setHasPermission] = useState(false);
  const [result, setResult] = useState<{ title: string; artist: string } | null>(null);
  const [pulseAnim] = useState(new Animated.Value(1));
  const colorScheme = useColorScheme();

  useEffect(() => {
    requestPermissions();
  }, []);

  useEffect(() => {
    if (isRecording) {
      Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.3,
            duration: 1000,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 1000,
            useNativeDriver: true,
          }),
        ])
      ).start();
    } else {
      pulseAnim.setValue(1);
    }
  }, [isRecording]);

  const requestPermissions = async () => {
    const { status } = await Audio.requestPermissionsAsync();
    setHasPermission(status === 'granted');
  };

  const startRecording = async () => {
    try {
      if (!hasPermission) {
        await requestPermissions();
        return;
      }

      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      const { recording: newRecording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );
      setRecording(newRecording);
      setIsRecording(true);
      setResult(null);

      // Simulate song recognition after 3 seconds
      setTimeout(() => {
        stopRecording(newRecording);
      }, 3000);
    } catch (err) {
      console.error('Failed to start recording', err);
    }
  };

  const stopRecording = async (recordingInstance?: Audio.Recording) => {
    const recordingToStop = recordingInstance || recording;
    if (!recordingToStop) return;

    try {
      await recordingToStop.stopAndUnloadAsync();
      setIsRecording(false);
      setRecording(null);

      // Mock song recognition result
      const mockSongs = [
        { title: 'Blinding Lights', artist: 'The Weeknd' },
        { title: 'Shape of You', artist: 'Ed Sheeran' },
        { title: 'Levitating', artist: 'Dua Lipa' },
        { title: 'Watermelon Sugar', artist: 'Harry Styles' },
        { title: 'Bad Guy', artist: 'Billie Eilish' },
      ];
      const randomSong = mockSongs[Math.floor(Math.random() * mockSongs.length)];
      setResult(randomSong);

      // Save to history
      const savedHistory = await getHistory();
      savedHistory.unshift({ ...randomSong, timestamp: Date.now() });
      await saveHistory(savedHistory.slice(0, 50)); // Keep last 50
    } catch (err) {
      console.error('Failed to stop recording', err);
    }
  };

  const getHistory = async (): Promise<any[]> => {
    // In a real app, use AsyncStorage
    return [];
  };

  const saveHistory = async (history: any[]) => {
    // In a real app, use AsyncStorage
  };

  return (
    <ThemedView style={styles.container}>
      <View style={styles.header}>
        <ThemedText type="title" style={styles.title}>
          Tap to Shazam
        </ThemedText>
      </View>

      <View style={styles.buttonContainer}>
        <TouchableOpacity
          onPress={isRecording ? undefined : startRecording}
          activeOpacity={0.8}
          disabled={isRecording}
        >
          <Animated.View
            style={[
              styles.shazamButton,
              {
                transform: [{ scale: pulseAnim }],
                backgroundColor: isRecording ? '#1DB954' : '#0066FF',
              },
            ]}
          >
            <ThemedText style={styles.buttonText}>S</ThemedText>
          </Animated.View>
        </TouchableOpacity>

        {isRecording && (
          <ThemedText style={styles.statusText}>Listening...</ThemedText>
        )}
      </View>

      {result && (
        <View style={styles.resultContainer}>
          <ThemedText type="subtitle" style={styles.resultTitle}>
            {result.title}
          </ThemedText>
          <ThemedText style={styles.resultArtist}>{result.artist}</ThemedText>
        </View>
      )}

      {!hasPermission && (
        <View style={styles.permissionContainer}>
          <ThemedText style={styles.permissionText}>
            Microphone permission required
          </ThemedText>
        </View>
      )}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  header: {
    position: 'absolute',
    top: 80,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
  },
  buttonContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  shazamButton: {
    width: 200,
    height: 200,
    borderRadius: 100,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  buttonText: {
    fontSize: 80,
    fontWeight: 'bold',
    color: '#fff',
  },
  statusText: {
    marginTop: 24,
    fontSize: 18,
    fontWeight: '600',
  },
  resultContainer: {
    position: 'absolute',
    bottom: 100,
    alignItems: 'center',
    paddingHorizontal: 32,
  },
  resultTitle: {
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 8,
  },
  resultArtist: {
    fontSize: 20,
    textAlign: 'center',
    opacity: 0.7,
  },
  permissionContainer: {
    position: 'absolute',
    bottom: 50,
    paddingHorizontal: 32,
  },
  permissionText: {
    fontSize: 14,
    textAlign: 'center',
    opacity: 0.7,
  },
});
