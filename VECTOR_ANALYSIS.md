# Vector-Based Spam Detection for Splam

## Overview

Vector analysis transforms text into numerical representations that can be compared using distance metrics. By clustering known spam and ham into vector space, we can determine if new content is "closer" to spam or legitimate content.

## Conceptual Foundation

### The Idea

```
Ham Cluster                    Spam Cluster
    🟢                            🔴
  🟢 🟢                        🔴 🔴 🔴
    🟢                          🔴 🔴

              ❓
         (New content)

Distance to ham: 2.3
Distance to spam: 5.7
→ Probably legitimate!
```

### Why This Works

1. **Semantic similarity**: Similar content clusters together
2. **Generalization**: Catches spam variations without explicit rules
3. **Adaptable**: New spam patterns update clusters automatically
4. **Probabilistic**: Returns confidence scores, not binary decisions

## Implementation Approaches

### Level 1: TF-IDF Vectors (Simple, Fast)

**Complexity**: Low
**Performance**: Good
**Dependencies**: None (pure Ruby)

#### How It Works

1. Build vocabulary from training corpus
2. Convert each document to TF-IDF vector
3. Cluster spam/ham using centroids
4. Compare new content to cluster centroids

#### Implementation

```ruby
class Splam::VectorAnalyzer
  attr_reader :vocabulary, :spam_centroid, :ham_centroid, :idf_scores

  def initialize
    @vocabulary = {}  # word -> index mapping
    @idf_scores = {}  # word -> IDF score
    @spam_centroid = nil
    @ham_centroid = nil
  end

  # Build vocabulary and IDF scores from corpus
  def train(spam_docs, ham_docs)
    all_docs = spam_docs + ham_docs

    # Build vocabulary
    @vocabulary = build_vocabulary(all_docs)

    # Calculate IDF scores
    @idf_scores = calculate_idf(all_docs)

    # Convert documents to vectors
    spam_vectors = spam_docs.map { |doc| doc_to_tfidf_vector(doc) }
    ham_vectors = ham_docs.map { |doc| doc_to_tfidf_vector(doc) }

    # Calculate centroids (mean of all vectors)
    @spam_centroid = calculate_centroid(spam_vectors)
    @ham_centroid = calculate_centroid(ham_vectors)

    # Optionally: Store all vectors for k-NN approach
    @spam_vectors = spam_vectors
    @ham_vectors = ham_vectors
  end

  # Classify new document
  def classify(text)
    vector = doc_to_tfidf_vector(text)

    spam_distance = cosine_distance(vector, @spam_centroid)
    ham_distance = cosine_distance(vector, @ham_centroid)

    # Convert distances to probability
    # Closer distance = higher probability
    spam_prob = 1.0 / (1.0 + spam_distance)
    ham_prob = 1.0 / (1.0 + ham_distance)

    # Normalize to probabilities
    total = spam_prob + ham_prob
    spam_probability = spam_prob / total

    {
      spam_probability: spam_probability,
      ham_probability: 1.0 - spam_probability,
      spam_distance: spam_distance,
      ham_distance: ham_distance,
      confidence: (spam_probability - 0.5).abs * 2  # 0 = uncertain, 1 = certain
    }
  end

  private

  def build_vocabulary(documents)
    vocab = {}
    index = 0

    documents.each do |doc|
      tokens = tokenize(doc)
      tokens.each do |token|
        unless vocab.key?(token)
          vocab[token] = index
          index += 1
        end
      end
    end

    vocab
  end

  def calculate_idf(documents)
    # IDF = log(N / df) where N = total docs, df = docs containing term
    doc_count = documents.size
    term_doc_freq = Hash.new(0)

    documents.each do |doc|
      tokens = tokenize(doc).uniq
      tokens.each { |token| term_doc_freq[token] += 1 }
    end

    idf = {}
    term_doc_freq.each do |term, df|
      idf[term] = Math.log(doc_count.to_f / df)
    end

    idf
  end

  def doc_to_tfidf_vector(text)
    tokens = tokenize(text)
    vector = Array.new(@vocabulary.size, 0.0)

    # Calculate term frequency
    tf = Hash.new(0)
    tokens.each { |token| tf[token] += 1 }

    # Convert to TF-IDF
    tf.each do |term, freq|
      next unless @vocabulary.key?(term)

      index = @vocabulary[term]
      idf = @idf_scores[term] || 0
      vector[index] = freq * idf
    end

    # Normalize vector
    normalize_vector(vector)
  end

  def calculate_centroid(vectors)
    return nil if vectors.empty?

    centroid = Array.new(vectors.first.size, 0.0)

    vectors.each do |vector|
      vector.each_with_index do |val, i|
        centroid[i] += val
      end
    end

    # Average
    centroid.map! { |val| val / vectors.size }
    centroid
  end

  def cosine_distance(v1, v2)
    # Cosine similarity = dot(v1, v2) / (||v1|| * ||v2||)
    # Distance = 1 - similarity

    dot_product = v1.zip(v2).sum { |a, b| a * b }
    magnitude1 = Math.sqrt(v1.sum { |x| x ** 2 })
    magnitude2 = Math.sqrt(v2.sum { |x| x ** 2 })

    return 1.0 if magnitude1.zero? || magnitude2.zero?

    similarity = dot_product / (magnitude1 * magnitude2)
    1.0 - similarity  # Convert to distance
  end

  def normalize_vector(vector)
    magnitude = Math.sqrt(vector.sum { |x| x ** 2 })
    return vector if magnitude.zero?
    vector.map { |x| x / magnitude }
  end

  def tokenize(text)
    Splam::Ngram.tokenize(text)
  end
end

# Usage in a rule
class Splam::Rules::VectorClassifier < Splam::Rule
  @@analyzer = nil

  def self.train_from_fixtures
    spam_docs = Dir.glob("test/fixtures/comment/spam/*.txt").map { |f| File.read(f) }
    ham_docs = Dir.glob("test/fixtures/comment/ham/*.txt").map { |f| File.read(f) }

    @@analyzer = Splam::VectorAnalyzer.new
    @@analyzer.train(spam_docs, ham_docs)
  end

  def run
    return unless @@analyzer

    result = @@analyzer.classify(@body)

    if result[:spam_probability] > 0.5
      score = ((result[:spam_probability] - 0.5) * 400).to_i  # 0-200 scale
      confidence = (result[:confidence] * 100).round
      add_score score, "Vector analysis: #{(result[:spam_probability] * 100).round}% spam (#{confidence}% confident)"
    else
      # Reduce score for likely ham
      score = ((0.5 - result[:spam_probability]) * 100).to_i
      add_score -score, "Vector analysis: #{(result[:ham_probability] * 100).round}% ham"
    end
  end
end

# Initialize on startup
Splam::Rules::VectorClassifier.train_from_fixtures
```

**Pros**:
- No external dependencies
- Fast training and inference
- Interpretable (can see which terms matter)
- Works with existing infrastructure

**Cons**:
- High-dimensional sparse vectors
- Doesn't capture word order or semantics
- Requires enough training data

---

### Level 2: N-gram Vectors with Clustering

**Complexity**: Medium
**Performance**: Better
**Dependencies**: Existing ngram infrastructure

#### Enhancement to Existing System

The current `Splam::Ngram` already creates trigrams. Let's use them for clustering:

```ruby
class Splam::VectorAnalyzer::Ngrams
  def initialize(n: 3)
    @n = n
    @spam_clusters = []  # Multiple spam clusters
    @ham_clusters = []   # Multiple ham clusters
  end

  def train(spam_docs, ham_docs, k_clusters: 5)
    # Convert documents to ngram vectors
    spam_vectors = spam_docs.map { |doc| doc_to_ngram_vector(doc) }
    ham_vectors = ham_docs.map { |doc| doc_to_ngram_vector(doc) }

    # Cluster spam into k clusters using k-means
    @spam_clusters = kmeans_clustering(spam_vectors, k_clusters)
    @ham_clusters = kmeans_clustering(ham_vectors, k_clusters)
  end

  def classify(text)
    vector = doc_to_ngram_vector(text)

    # Find distance to nearest cluster in each category
    min_spam_distance = @spam_clusters.map { |centroid|
      cosine_distance(vector, centroid)
    }.min

    min_ham_distance = @ham_clusters.map { |centroid|
      cosine_distance(vector, centroid)
    }.min

    # Also check average distance to all clusters
    avg_spam_distance = @spam_clusters.sum { |c| cosine_distance(vector, c) } / @spam_clusters.size
    avg_ham_distance = @ham_clusters.sum { |c| cosine_distance(vector, c) } / @ham_clusters.size

    {
      nearest_spam: min_spam_distance,
      nearest_ham: min_ham_distance,
      avg_spam: avg_spam_distance,
      avg_ham: avg_ham_distance,
      spam_probability: calculate_probability(min_spam_distance, min_ham_distance)
    }
  end

  private

  def doc_to_ngram_vector(text)
    # Use existing Splam::Ngram.trigram
    ngrams = Splam::Ngram.trigram(text)

    # Convert to vector (ngram -> frequency)
    ngrams
  end

  def kmeans_clustering(vectors, k, max_iterations: 50)
    # Simple k-means implementation
    return [calculate_centroid_from_ngrams(vectors)] if k == 1

    # Initialize centroids randomly
    centroids = vectors.sample(k)

    max_iterations.times do
      # Assign each vector to nearest centroid
      clusters = Array.new(k) { [] }

      vectors.each do |vector|
        nearest = centroids.each_with_index.min_by { |centroid, _|
          ngram_distance(vector, centroid)
        }
        clusters[nearest[1]] << vector
      end

      # Update centroids
      new_centroids = clusters.map { |cluster|
        cluster.empty? ? centroids.sample : calculate_centroid_from_ngrams(cluster)
      }

      # Check convergence
      break if new_centroids == centroids
      centroids = new_centroids
    end

    centroids
  end

  def calculate_centroid_from_ngrams(ngram_vectors)
    # Average all ngram frequencies
    centroid = Hash.new(0.0)

    ngram_vectors.each do |ngrams|
      ngrams.each do |ngram, freq|
        centroid[ngram] += freq
      end
    end

    # Average
    count = ngram_vectors.size
    centroid.transform_values { |v| v / count }
  end

  def ngram_distance(ngrams1, ngrams2)
    # Jaccard distance or cosine distance on ngram frequencies
    all_ngrams = (ngrams1.keys + ngrams2.keys).uniq

    v1 = all_ngrams.map { |ng| ngrams1[ng] || 0 }
    v2 = all_ngrams.map { |ng| ngrams2[ng] || 0 }

    cosine_distance_arrays(v1, v2)
  end

  def calculate_probability(spam_dist, ham_dist)
    # Inverse distance weighted
    spam_score = 1.0 / (1.0 + spam_dist)
    ham_score = 1.0 / (1.0 + ham_dist)
    spam_score / (spam_score + ham_score)
  end
end
```

**Benefits over Level 1**:
- Captures word order (trigrams)
- Multiple clusters catch spam subtypes
- Uses existing infrastructure
- More robust to spam variations

---

### Level 3: Embedding Vectors (Advanced)

**Complexity**: High
**Performance**: Best
**Dependencies**: External embedding model

#### Pre-trained Word Embeddings

Use Word2Vec, GloVe, or FastText embeddings:

```ruby
require 'word2vec'  # Or similar gem

class Splam::VectorAnalyzer::Embeddings
  def initialize(embedding_file = 'glove.6B.100d.txt')
    @embeddings = load_embeddings(embedding_file)
    @embedding_dim = 100  # or 300
  end

  def doc_to_vector(text)
    tokens = Splam::Ngram.tokenize(text)

    # Get embedding for each token
    vectors = tokens.map { |token| @embeddings[token] }.compact

    return nil if vectors.empty?

    # Average all word vectors (simple but effective)
    average_vectors(vectors)
  end

  def train(spam_docs, ham_docs)
    spam_vectors = spam_docs.map { |doc| doc_to_vector(doc) }.compact
    ham_vectors = ham_docs.map { |doc| doc_to_vector(doc) }.compact

    # Use k-means or DBSCAN for clustering
    @spam_clusters = kmeans_clustering(spam_vectors, k: 5)
    @ham_clusters = kmeans_clustering(ham_vectors, k: 5)
  end

  def classify(text)
    vector = doc_to_vector(text)
    return { spam_probability: 0.5 } unless vector  # Unknown

    spam_distances = @spam_clusters.map { |c| euclidean_distance(vector, c) }
    ham_distances = @ham_clusters.map { |c| euclidean_distance(vector, c) }

    min_spam = spam_distances.min
    min_ham = ham_distances.min

    # Convert to probability
    spam_prob = 1.0 / (1.0 + min_spam)
    ham_prob = 1.0 / (1.0 + min_ham)

    {
      spam_probability: spam_prob / (spam_prob + ham_prob),
      spam_distance: min_spam,
      ham_distance: min_ham,
      semantic_similarity: calculate_semantic_similarity(vector)
    }
  end

  private

  def load_embeddings(file)
    # Load pre-trained embeddings
    # Format: word float1 float2 ... floatN
    embeddings = {}

    File.readlines(file).each do |line|
      parts = line.split
      word = parts[0]
      vector = parts[1..-1].map(&:to_f)
      embeddings[word] = vector
    end

    embeddings
  end

  def average_vectors(vectors)
    dim = vectors.first.size
    avg = Array.new(dim, 0.0)

    vectors.each do |vector|
      vector.each_with_index { |val, i| avg[i] += val }
    end

    avg.map { |val| val / vectors.size }
  end

  def euclidean_distance(v1, v2)
    Math.sqrt(v1.zip(v2).sum { |a, b| (a - b) ** 2 })
  end
end
```

**Benefits**:
- Captures semantic meaning
- "viagra" and "pills" are similar in vector space
- Generalizes to unseen words
- State-of-the-art performance

**Drawbacks**:
- Requires pre-trained embeddings (large files)
- More complex deployment
- Slower inference

---

### Level 4: Sentence Embeddings (State-of-the-art)

**Complexity**: Very High
**Performance**: Excellent
**Dependencies**: Python/ONNX

Use modern sentence embedding models like Sentence-BERT:

```ruby
# Interface with Python service or ONNX runtime
class Splam::VectorAnalyzer::SentenceBERT
  def initialize
    # Load model (via ONNX or Python service)
    @model = load_sentence_bert_model
  end

  def doc_to_vector(text)
    # Get 768-dimensional vector for entire document
    @model.encode(text)
  end

  # Same training/clustering logic as above
  # but with much better vectors
end
```

**Benefits**:
- Best semantic understanding
- Captures context across entire document
- Robust to paraphrasing

**Drawbacks**:
- Complex deployment (Python dependency or ONNX)
- Slower inference (100-500ms)
- Larger memory footprint

---

## Hybrid Approach: Best of Both Worlds

Combine vector analysis with existing rules:

```ruby
class Splam::Rules::HybridAnalyzer < Splam::Rule
  def run
    # 1. Fast heuristics first
    heuristic_score = run_heuristics(@body)

    # 2. If borderline, use vector analysis
    if heuristic_score.between?(50, 150)
      vector_result = @@vector_analyzer.classify(@body)

      if vector_result[:spam_probability] > 0.7
        add_score 100, "Vector analysis: High spam probability #{(vector_result[:spam_probability] * 100).round}%"
      elsif vector_result[:spam_probability] < 0.3
        add_score -50, "Vector analysis: High ham probability"
      else
        add_score 25, "Vector analysis: Uncertain #{(vector_result[:spam_probability] * 100).round}%"
      end
    elsif heuristic_score > 150
      # Already clearly spam, no need for expensive vector analysis
      add_score 0, "Skipped vector analysis (already spam)"
    else
      # Clearly ham
      add_score 0, "Skipped vector analysis (clearly ham)"
    end
  end

  private

  def run_heuristics(text)
    # Quick checks: bad words, link count, etc.
    score = 0
    score += 50 if text =~ /viagra|cialis/
    score += 30 if text.scan(/https?:\/\//).size > 3
    score
  end
end
```

---

## Advanced: Anomaly Detection

Instead of binary spam/ham, detect **outliers**:

```ruby
class Splam::VectorAnalyzer::AnomalyDetector
  def train(legitimate_docs)
    # Only train on legitimate content (ham)
    vectors = legitimate_docs.map { |doc| doc_to_vector(doc) }

    # Calculate mean and covariance
    @mean = calculate_mean(vectors)
    @covariance = calculate_covariance(vectors, @mean)

    # Determine threshold (e.g., 95th percentile)
    distances = vectors.map { |v| mahalanobis_distance(v, @mean, @covariance) }
    @threshold = percentile(distances, 0.95)
  end

  def classify(text)
    vector = doc_to_vector(text)
    distance = mahalanobis_distance(vector, @mean, @covariance)

    {
      is_outlier: distance > @threshold,
      anomaly_score: distance,
      threshold: @threshold,
      deviation: (distance / @threshold) - 1.0  # How far beyond threshold
    }
  end

  private

  def mahalanobis_distance(vector, mean, covariance)
    # Distance that accounts for correlation between dimensions
    diff = vector.zip(mean).map { |a, b| a - b }
    Math.sqrt(matrix_multiply(diff, covariance, diff))
  end
end
```

**Benefits**:
- Only needs ham examples (easier to get clean data)
- Catches novel spam types
- No spam examples needed for training

---

## Practical Recommendation: Start Simple

### Phase 1: TF-IDF with Centroids (Weeks 1-2)

```ruby
# Initialize once
analyzer = Splam::VectorAnalyzer.new
analyzer.train(spam_docs, ham_docs)

# Save to file
File.write('splam_vectors.json', analyzer.to_json)

# Load in production
analyzer = Splam::VectorAnalyzer.from_json(File.read('splam_vectors.json'))
```

### Phase 2: Add Clustering (Weeks 3-4)

- Move from single centroid to k-means clusters
- Capture spam subtypes (pharma spam, link spam, etc.)

### Phase 3: Experiment with Embeddings (Weeks 5-8)

- Try Word2Vec or GloVe
- Measure improvement over TF-IDF
- A/B test in production

### Phase 4: Production Optimization

- Cache vectors for common tokens
- Use approximate nearest neighbors (FAISS)
- Background clustering updates

---

## Integration with Existing System

```ruby
class Comment
  include Splam

  splammable :body do |suite|
    suite.threshold = 120

    # Traditional rules for quick checks
    suite.rules = {
      Splam::Rules::BadWords => 1.0,
      Splam::Rules::Href => 1.0,
      Splam::Rules::Bbcode => 1.0,

      # Vector analysis for nuanced classification
      Splam::Rules::VectorClassifier => 2.0  # High weight
    }
  end
end
```

---

## Evaluation Metrics

Track performance:

```ruby
class Splam::VectorEvaluator
  def evaluate(test_docs, labels)
    predictions = test_docs.map { |doc|
      @@analyzer.classify(doc)[:spam_probability] > 0.5
    }

    tp = predictions.zip(labels).count { |pred, label| pred && label }
    fp = predictions.zip(labels).count { |pred, label| pred && !label }
    fn = predictions.zip(labels).count { |pred, label| !pred && label }
    tn = predictions.zip(labels).count { |pred, label| !pred && !label }

    {
      precision: tp.to_f / (tp + fp),
      recall: tp.to_f / (tp + fn),
      f1_score: 2.0 * tp / (2.0 * tp + fp + fn),
      accuracy: (tp + tn).to_f / test_docs.size
    }
  end
end
```

---

## Next Steps

1. **Prototype TF-IDF approach** using existing test fixtures
2. **Measure baseline performance** against current rules
3. **A/B test** in production with small percentage of traffic
4. **Iterate** based on false positive/negative rates
5. **Consider embeddings** if TF-IDF performance plateaus

The beauty of vector analysis is it's **data-driven and adaptive**. As you collect more spam/ham, the clusters automatically improve!
